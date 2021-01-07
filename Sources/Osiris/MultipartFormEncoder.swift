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

extension MultipartFormEncoder {
    struct BodyData {
        let contentType: String
        let data: Data

        var contentLength: Int {
            data.count
        }
    }

    struct BodyFile {
        let contentType: String
        let url: URL
        let contentLength: Int64
    }

    struct Part {
        enum Content {
            case text(String)
            case binaryData(Data, type: String, filename: String)
            case binaryFile(URL, size: Int64, type: String, filename: String)
        }

        let name: String
        let content: Content

        static func text(_ value: String, name: String) -> Part {
            Part(name: name, content: .text(value))
        }

        static func data(_ data: Data, name: String, type: String, filename: String) -> Part {
            Part(name: name, content: .binaryData(data, type: type, filename: filename))
        }

        static func file(_ url: URL, name: String, type: String, filename: String? = nil) throws -> Part {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int64 else {
                throw Error.invalidFile(url)
            }
            return Part(name: name, content: .binaryFile(url, size: size, type: type, filename: filename ?? url.lastPathComponent))
        }
    }
}

final class MultipartFormEncoder {
    enum Error: Swift.Error {
        case invalidFile(URL)
        case invalidOutputFile(URL)
        case streamError
        case emptyData
        case tooMuchDataForMemory
    }

    let boundary: String

    init(boundary: String? = nil) {
        self.boundary = boundary ?? "Osiris-\(UUID().uuidString)"
    }

    func encodeData(parts: [Part]) throws -> BodyData {
        let totalSize: Int64 = parts.reduce(0, { size, part in
            switch part.content {
            case let .text(string):
                return size + Int64(string.lengthOfBytes(using: .utf8))

            case let .binaryData(data, _, _):
                return size + Int64(data.count)

            case let .binaryFile(_, fileSize, _, _):
                return size + fileSize
            }
        })
        guard totalSize < 50_000_000 else {
            throw Error.tooMuchDataForMemory
        }

        let stream = OutputStream(toMemory: ())
        stream.open()

        for part in parts {
            try encodePart(part, to: stream)
        }

        // Footer
        try encode(string: "--\(boundary)--", to: stream)

        stream.close()

        guard let bodyData = stream.property(forKey: .dataWrittenToMemoryStreamKey) as? Data else {
            throw Error.streamError
        }
        return BodyData(contentType: "multipart/form-data; boundary=\"\(boundary)\"", data: bodyData)
    }

    func encodeFile(parts: [Part]) throws -> BodyFile {
        let fm = FileManager.default
        let outputURL = tempFileURL()
        guard let stream = OutputStream(url: outputURL, append: false) else {
            _ = try? fm.removeItem(at: outputURL)
            throw Error.invalidFile(outputURL)
        }
        stream.open()

        for part in parts {
            try encodePart(part, to: stream)
        }

        // Footer
        try encode(string: "--\(boundary)--", to: stream)

        stream.close()

        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        guard let size = attributes[.size] as? Int64 else {
            throw Error.invalidOutputFile(outputURL)
        }
        let contentType = "multipart/form-data; boundary=\(boundary)"
        return BodyFile(contentType: contentType, url: outputURL, contentLength: size)
    }

    private func tempFileURL() -> URL {
        let timestamp = Int(Date().timeIntervalSince1970)
        let filename = "multipart-\(timestamp)-\(Int.random(in: 0 ... .max))"
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
        return url
    }

    private func encodePart(_ part: Part, to stream: OutputStream) throws {
        // Header
        try encode(string: "--\(boundary)\r\n", to: stream)
        switch part.content {
        case .text:
            try encode(string: "Content-Disposition: form-data; name=\"\(part.name)\"\r\n", to: stream)

        case let .binaryData(data, type, filename):
            try encode(string: "Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n", to: stream)
            try encode(string: "Content-Type: \(type)\r\n", to: stream)
            try encode(string: "Content-Length: \(data.count)\r\n", to: stream)

        case let .binaryFile(_, size, type, filename):
            try encode(string: "Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n", to: stream)
            try encode(string: "Content-Type: \(type)\r\n", to: stream)
            try encode(string: "Content-Length: \(size)\r\n", to: stream)
        }
        try encode(string: "\r\n", to: stream)

        // Body
        switch part.content {
        case let .text(string):
            try encode(string: string, to: stream)

        case let .binaryData(data, _, _):
            try encode(data: data, to: stream)

        case let .binaryFile(url, _, _, _):
            try encode(url: url, to: stream)
        }
        try encode(string: "\r\n", to: stream)
    }

    private func encode(data: Data, to stream: OutputStream) throws {
        guard !data.isEmpty else {
            throw Error.emptyData
        }
        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let uint8Bytes = bytes.baseAddress!.bindMemory(to: UInt8.self, capacity: bytes.count)
            let written = stream.write(uint8Bytes, maxLength: bytes.count)
            if written < 0 {
                throw Error.streamError
            }
        }
    }

    private func encode(string: String, to stream: OutputStream) throws {
        try encode(data: Data(string.utf8), to: stream)
    }

    private func encode(url: URL, to stream: OutputStream) throws {
        guard let inStream = InputStream(url: url) else {
            throw Error.streamError
        }
        let bufferSize = 128 * 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        inStream.open()

        defer {
            buffer.deallocate()
            inStream.close()
        }

        while inStream.hasBytesAvailable {
            let bytesRead = inStream.read(buffer, maxLength: bufferSize)
            guard bytesRead > 0 else {
                throw Error.streamError
            }

            let bytesWritten = stream.write(buffer, maxLength: bytesRead)
            if bytesWritten < 0 {
                throw Error.streamError
            }
        }
    }
}
