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
    
    /// Contains the encoded multipart form data for in-memory storage.
    public struct BodyData: CustomStringConvertible {
        
        /// The content type header value including boundary.
        public let contentType: String
        
        /// The encoded form data.
        public let data: Data

        /// The length of the encoded data in bytes.
        public var contentLength: Int {
            data.count
        }
        
        public var description: String {
            "<BodyData size=\(contentLength)>"
        }
    }

    /// Contains the encoded multipart form data written to a file for streaming.
    public struct BodyFile: CustomStringConvertible {
        
        /// The content type header value including boundary.
        public let contentType: String
        
        /// The URL of the temporary file containing the encoded data.
        public let url: URL
        
        /// The length of the encoded data in bytes.
        public let contentLength: Int64
        
        public var description: String {
            "<BodyFile file=\(url.lastPathComponent) size=\(contentLength)>"
        }
    }

    /// Represents a single part in a multipart form.
    public struct Part: Equatable, Sendable, CustomStringConvertible {

        /// The content types supported in multipart forms.
        public enum Content: Equatable, Sendable, CustomStringConvertible {
            
            /// Plain text content.
            case text(String)
            
            /// Binary data with MIME type and filename.
            case binaryData(Data, type: String, filename: String)
            
            /// Binary data from a file with size, MIME type and filename.
            case binaryFile(URL, size: Int64, type: String, filename: String)
            
            public var description: String {
                switch self {
                case let .text(value):
                    let preview = value.count > 50 ? "\(value.prefix(50))..." : value
                    return "<Content.text value=\"\(preview)\">"
                case let .binaryData(data, type, filename):
                    return "<Content.binaryData size=\(data.count) type=\(type) filename=\(filename)>"
                case let .binaryFile(url, size, type, filename):
                    return "<Content.binaryFile file=\(url.lastPathComponent) size=\(size) type=\(type) filename=\(filename)>"
                }
            }
        }

        /// The form field name for this part.
        public let name: String
        
        /// The content of this part.
        public let content: Content

        /// Creates a text part for the multipart form.
        /// - Parameters:
        ///   - value: The text value to include
        ///   - name: The form field name
        /// - Returns: A configured Part instance
        public static func text(_ value: String, name: String) -> Part {
            Part(name: name, content: .text(value))
        }

        /// Creates a binary data part for the multipart form.
        /// - Parameters:
        ///   - data: The binary data to include
        ///   - name: The form field name
        ///   - type: The MIME type of the data
        ///   - filename: The filename to report to the server
        /// - Returns: A configured Part instance
        public static func data(_ data: Data, name: String, type: String, filename: String) -> Part {
            Part(name: name, content: .binaryData(data, type: type, filename: filename))
        }

        /// Creates a file part for the multipart form by reading from disk.
        /// - Parameters:
        ///   - url: The file URL to read from
        ///   - name: The form field name
        ///   - type: The MIME type of the file
        ///   - filename: The filename to report to the server (defaults to the file's name)
        /// - Returns: A configured Part instance
        /// - Throws: `Error.invalidFile` if the file cannot be read or sized
        public static func file(_ url: URL, name: String, type: String, filename: String? = nil) throws -> Part {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let size = attributes[.size] as? Int64 else {
                throw Error.invalidFile(url)
            }
            return Part(name: name, content: .binaryFile(url, size: size, type: type, filename: filename ?? url.lastPathComponent))
        }
        
        public var description: String {
            "<Part name=\(name) content=\(content)>"
        }
    }
}

/// A multipart/form-data encoder that can encode forms either to memory or to files for streaming.
///
/// This encoder supports text fields, binary data, and file uploads in a single multipart form.
/// It can encode forms either to memory (with a 50MB limit) or directly to temporary files for
/// streaming large amounts of data.
///
/// ## Usage
///
/// ```swift
/// let encoder = MultipartFormEncoder()
/// let parts: [MultipartFormEncoder.Part] = [
///     .text("jane@example.net", name: "email"),
///     .data(imageData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg")
/// ]
/// 
/// // Encode to memory (< 50MB)
/// let bodyData = try encoder.encodeData(parts: parts)
/// 
/// // Or encode to file for streaming
/// let bodyFile = try encoder.encodeFile(parts: parts)
/// ```
public final class MultipartFormEncoder: CustomStringConvertible {
    
    /// Errors that can occur during multipart encoding.
    public enum Error: Swift.Error, CustomStringConvertible {
        
        /// The specified file cannot be read or is invalid.
        case invalidFile(URL)
        
        /// The output file cannot be created or written to.
        case invalidOutputFile(URL)
        
        /// An error occurred while reading from or writing to a stream.
        case streamError
        
        /// The total data size exceeds the 50MB limit for in-memory encoding.
        case tooMuchDataForMemory
        
        public var description: String {
            switch self {
            case let .invalidFile(url):
                return "<MultipartFormEncoder.Error.invalidFile file=\(url.lastPathComponent)>"
            case let .invalidOutputFile(url):
                return "<MultipartFormEncoder.Error.invalidOutputFile file=\(url.lastPathComponent)>"
            case .streamError:
                return "MultipartFormEncoder.Error.streamError"
            case .tooMuchDataForMemory:
                return "MultipartFormEncoder.Error.tooMuchDataForMemory"
            }
        }
    }

    /// The boundary string used to separate parts in the multipart form.
    public let boundary: String

    /// Creates a new multipart form encoder.
    /// - Parameter boundary: Optional custom boundary string. If nil, a unique boundary is generated.
    public init(boundary: String? = nil) {
        self.boundary = boundary ?? "Osiris-\(UUID().uuidString)"
    }

    /// Encodes the multipart form to memory as Data.
    ///
    /// This method has a hard limit of 50MB to prevent excessive memory usage.
    /// For larger forms, use `encodeFile(parts:)` instead.
    ///
    /// - Parameter parts: The parts to include in the multipart form
    /// - Returns: A BodyData containing the encoded form and content type
    /// - Throws: `Error.tooMuchDataForMemory` if the total size exceeds 50MB,
    ///           or `Error.streamError` if encoding fails
    public func encodeData(parts: [Part]) throws -> BodyData {
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

    /// Encodes the multipart form to a temporary file for streaming.
    ///
    /// This method is recommended for large forms or when memory usage is a concern.
    /// The returned file should be streamed using an InputStream and then deleted when no longer needed.
    ///
    /// - Parameter parts: The parts to include in the multipart form
    /// - Returns: A BodyFile containing the file URL, content type, and size
    /// - Throws: `Error.invalidFile` if the output file cannot be created,
    ///           `Error.invalidOutputFile` if the file size cannot be determined,
    ///           or `Error.streamError` if encoding fails
    public func encodeFile(parts: [Part]) throws -> BodyFile {
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
        guard !data.isEmpty else { return }

        try data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            let uint8Bytes = bytes.baseAddress!.bindMemory(to: UInt8.self, capacity: bytes.count)
            let written = stream.write(uint8Bytes, maxLength: bytes.count)
            if written != bytes.count {
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
                break
            }

            let bytesWritten = stream.write(buffer, maxLength: bytesRead)
            if bytesWritten != bytesRead {
                throw Error.streamError
            }
        }
    }
    
    public var description: String {
        "<MultipartFormEncoder boundary=\(boundary)>"
    }
}
