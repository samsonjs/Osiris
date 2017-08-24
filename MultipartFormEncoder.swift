//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify,
// merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be included in all copies
// or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

struct MultipartEncodingInMemory {
    let contentType: String
    let contentLength: Int64
    let body: Data
}

struct MultipartEncodingOnDisk {
    let contentType: String
    let contentLength: Int64
    let bodyFileURL: URL
}

enum MultipartFormEncodingError: Error {
    case invalidText(String)
    case invalidPath(String)
    case invalidPart(MultipartFormEncoder.Part)
    case internalError
    case streamError
}

final class MultipartFormEncoder {
    struct Part {
        let data: Data?
        let dataFileURL: URL?
        let encoding: String
        let filename: String?
        let length: Int64
        let name: String
        let type: String

        static func text(name: String, text: String) -> Part? {
            guard let data = text.data(using: .utf8) else {
                return nil
            }
            return Part(name: name, type: "text/plain; charset=utf-8", encoding: "8bit", data: data)
        }

        init(name: String, type: String, encoding: String, data: Data, filename: String? = nil) {
            self.dataFileURL = nil
            self.name = name
            self.type = type
            self.encoding = encoding
            self.data = data
            self.filename = filename
            self.length = Int64(data.count)
        }

        init(name: String, type: String, encoding: String, dataFileURL: URL, filename: String? = nil) {
            self.data = nil
            self.name = name
            self.type = type
            self.encoding = encoding
            self.dataFileURL = dataFileURL
            self.filename = filename
            self.length = FileManager.default.sizeOfFile(at: dataFileURL)
        }

        var isBinary: Bool {
            return encoding == "binary"
        }
    }

    let boundary: String

    private var parts: [Part] = []

    private var contentType: String {
        return "multipart/form-data; boundary=\"\(boundary)\""
    }

    private static let boundaryPrefix = "LifeIsMadeOfSeconds"

    class func generateBoundary() -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        return "\(boundaryPrefix)-\(timestamp)"
    }

    init(boundary: String? = nil) {
        self.boundary = boundary ?? MultipartFormEncoder.generateBoundary()
    }

    func addPart(_ part: Part) {
        assert(part.data != nil || part.dataFileURL != nil)
        parts.append(part)
    }

    func addText(name: String, text: String, filename: String? = nil) throws {
        guard let data = text.data(using: .utf8) else {
            throw MultipartFormEncodingError.invalidText(text)
        }
        let type = "text/plain; charset=utf-8"
        let part = Part(name: name, type: type, encoding: "8bit", data: data, filename: filename)
        parts.append(part)
    }

    func addBinary(name: String, contentType: String, data: Data, filename: String? = nil) {
        let part = Part(name: name, type: contentType, encoding: "binary", data: data, filename: filename)
        parts.append(part)
    }

    func addBinary(name: String, contentType: String, fileURL: URL, filename: String? = nil) {
        assert(FileManager.default.fileExists(atPath: fileURL.path))
        let part = Part(name: name, type: contentType, encoding: "binary", dataFileURL: fileURL, filename: filename)
        parts.append(part)
    }

    func encodeToMemory() throws -> MultipartEncodingInMemory {
        let stream = OutputStream.toMemory()
        stream.open()
        do {
            try encode(to: stream)
            stream.close()
            guard let data = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
                throw MultipartFormEncodingError.internalError
            }
            return MultipartEncodingInMemory(contentType: contentType, contentLength: Int64(data.count), body: data)
        }
        catch {
            stream.close()
            throw error
        }
    }

    func encodeToDisk(path: String) throws -> MultipartEncodingOnDisk {
        guard let stream = OutputStream(toFileAtPath: path, append: false) else {
            throw MultipartFormEncodingError.invalidPath(path)
        }
        stream.open()
        do {
            try encode(to: stream)
            stream.close()
            let fileURL = URL(fileURLWithPath: path)
            let length = FileManager.default.sizeOfFile(at: fileURL)
            return MultipartEncodingOnDisk(contentType: contentType, contentLength: length, bodyFileURL: fileURL)
        }
        catch {
            stream.close()
            _ = try? FileManager.default.removeItem(atPath: path)
            throw error
        }
    }

    // MARK: - Private methods

    private func encode(to stream: OutputStream) throws {
        for part in parts {
            try writeHeader(part, to: stream)
            try writeBody(part, to: stream)
            try writeFooter(part, to: stream)
        }
    }

    private let lineEnd = "\r\n".data(using: .utf8)!

    private func writeHeader(_ part: Part, to stream: OutputStream) throws {
        let disposition: String
        if let filename = part.filename {
            disposition = "Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\""
        }
        else {
            disposition = "Content-Disposition: form-data; name=\"\(part.name)\""
        }
        let header = [
            "--\(boundary)",
            disposition,
            "Content-Length: \(part.length)",
            "Content-Type: \(part.type)",
            "", // ends with a newline
        ].joined(separator: "\r\n")
        try writeString(header, to: stream)
        try writeData(lineEnd, to: stream)
    }

    private func writeBody(_ part: Part, to stream: OutputStream) throws {
        if let data = part.data {
            try writeData(data, to: stream)
        }
        else if let fileURL = part.dataFileURL {
            try writeFile(fileURL, to: stream)
        }
        else {
            throw MultipartFormEncodingError.invalidPart(part)
        }
        try writeData(lineEnd, to: stream)
    }

    private func writeFooter(_ part: Part, to stream: OutputStream) throws {
        let footer = "--\(boundary)--\r\n\r\n"
        try writeString(footer, to: stream)
    }

    private func writeString(_ string: String, to stream: OutputStream) throws {
        guard let data = string.data(using: .utf8) else {
            throw MultipartFormEncodingError.invalidText(string)
        }
        try writeData(data, to: stream)
    }

    private func writeData(_ data: Data, to stream: OutputStream) throws {
        guard !data.isEmpty else {
            log.warning("Ignoring request to write 0 bytes of data to stream \(stream)")
            return
        }
        try data.withUnsafeBytes { (bytes: UnsafePointer<UInt8>) throws -> Void in
            let written = stream.write(bytes, maxLength: data.count)
            if written < 0 {
                throw MultipartFormEncodingError.streamError
            }
        }
    }

    private func writeFile(_ url: URL, to stream: OutputStream) throws {
        guard let inStream = InputStream(fileAtPath: url.path) else {
            throw MultipartFormEncodingError.streamError
        }
        let bufferSize = 128 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        inStream.open()

        defer {
            buffer.deallocate(capacity: bufferSize)
            inStream.close()
        }

        while inStream.hasBytesAvailable {
            let bytesRead = inStream.read(buffer, maxLength: bufferSize)
            if bytesRead > 0 {
                let bytesWritten = stream.write(buffer, maxLength: bytesRead)
                if bytesWritten < 0 {
                    throw MultipartFormEncodingError.streamError
                }
            }
            else {
                throw MultipartFormEncodingError.streamError
            }
        }
    }
}
