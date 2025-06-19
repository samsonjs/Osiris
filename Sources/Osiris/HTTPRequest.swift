//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
import OSLog
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#endif

private let log = Logger(subsystem: "net.samhuri.Osiris", category: "HTTPRequest")

/// The body content of an HTTP request.
public enum HTTPRequestBody: Sendable {
    /// No body content.
    case none
    /// Parameters to be encoded as form data.
    case formParameters([String: any Sendable])
    /// Parameters to be encoded as JSON.
    case jsonParameters([String: any Sendable])
    /// Raw data with specified content type.
    case data(Data, contentType: UTType)
    /// Multipart form data parts.
    case multipart([MultipartFormEncoder.Part])
    /// File data to be streamed from disk.
    case fileData(URL)

    /// Returns true if this body represents no content.
    public var isEmpty: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}

/// A structure representing an HTTP request with support for various content types and multipart forms.
///
/// HTTPRequest provides a clean abstraction over URLRequest with built-in support for common
/// HTTP tasks like JSON encoding, form encoding, and multipart forms.
///
/// ## Usage
///
/// ```swift
/// // GET request with query parameters
/// let getRequest = HTTPRequest.get(
///     URL(string: "https://api.example.net/users")!,
///     parameters: ["page": "1", "limit": "10"]
/// )
///
/// // POST with JSON body
/// let jsonRequest = HTTPRequest.postJSON(
///     URL(string: "https://api.example.net/users")!,
///     body: ["name": "Chali 2na", "email": "chali@example.net"]
/// )
///
/// // DELETE with query parameters
/// let deleteRequest = HTTPRequest.delete(
///     URL(string: "https://api.example.net/users/123")!,
///     parameters: ["confirm": "true"]
/// )
///
/// // Multipart form with file upload
/// let uploadURL = URL(string: "https://api.example.net/upload")!
/// let multipartRequest = HTTPRequest.postMultipart(uploadURL, parts: [
///     .text("Trent Reznor", name: "name"),
///     .data(imageData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg")
/// ])
///
/// // File streaming for large request bodies
/// let fileRequest = HTTPRequest.postFile(
///     URL(string: "https://api.example.net/upload")!,
///     fileURL: URL(fileURLWithPath: "/path/to/large/file.zip")
/// )
///
/// // Custom content types like XML
/// let xmlData = "<request><artist>Nine Inch Nails</artist></request>".data(using: .utf8)!
/// let xmlRequest = HTTPRequest.post(
///     URL(string: "https://api.example.net/music")!,
///     data: xmlData,
///     contentType: .xml
/// )
/// ```
public struct HTTPRequest: Sendable, CustomStringConvertible {

    /// The HTTP method for this request.
    public var method: HTTPMethod

    /// The target URL for this request.
    public var url: URL

    /// The body content for this request.
    public var body: HTTPRequestBody

    /// Additional HTTP headers for the request.
    public var headers: [String: String] = [:]

    // MARK: - Deprecated Properties

    /// Parameters to be encoded according to the content type.
    @available(*, deprecated, message: "Access parameters through the body property instead")
    public var parameters: [String: any Sendable]? {
        get {
            switch body {
            case .formParameters(let params), .jsonParameters(let params):
                return params
            default:
                return nil
            }
        }
        set {
            guard let newValue = newValue else {
                body = .none
                return
            }
            // Preserve existing encoding type if possible
            switch body {
            case .jsonParameters:
                body = .jsonParameters(newValue)
            case .formParameters, .none:
                body = .formParameters(newValue)
            default:
                // Can't set parameters on other body types
                break
            }
        }
    }

    /// Multipart form parts.
    @available(*, deprecated, message: "Use postMultipart(_:parts:) or access parts through the body property")
    public var parts: [MultipartFormEncoder.Part] {
        get {
            if case .multipart(let parts) = body {
                return parts
            }
            return []
        }
        set {
            body = .multipart(newValue)
        }
    }

    /// The content type for the request body (computed from body content).
    public var contentType: HTTPContentType {
        switch body {
        case .none:
            return .none
        case .formParameters:
            // For GET/DELETE, parameters go in query string, so no body content type
            if method == .get || method == .delete {
                return .none
            }
            return .formEncoded
        case .jsonParameters:
            // For GET/DELETE, parameters go in query string, so no body content type
            if method == .get || method == .delete {
                return .none
            }
            return .json
        case let .data(_, contentType):
            if let mimeType = contentType.preferredMIMEType {
                return .custom(mimeType)
            } else {
                log.warning("No MIME type found for UTType \(contentType), falling back to application/octet-stream")
                return .custom("application/octet-stream")
            }
        case .multipart:
            return .multipart
        case .fileData:
            return .none
        }
    }

    /// Creates a new HTTP request, verifying that no body is provided for GET and DELETE requests. When a body is provided with
    /// those requests then an error is thrown.
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The target URL
    ///   - body: The body content for the request
    /// - Throws: HTTPRequestError.invalidRequestBody if GET or DELETE request has a body
    public init(method: HTTPMethod, url: URL, body: HTTPRequestBody = .none) throws {
        guard method != .get && method != .delete || body.isEmpty else {
            throw HTTPRequestError.invalidRequestBody
        }
        self.method = method
        self.url = url
        self.body = body
    }

    /// Internal initializer that bypasses validation for convenience methods that we don't want to be throwing in the public API.
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The target URL
    ///   - body: The body content for the request
    init(uncheckedMethod method: HTTPMethod, url: URL, body: HTTPRequestBody = .none) {
        self.method = method
        self.url = url
        self.body = body
    }

    /// Creates a new HTTP request with the old API.
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    @available(*, deprecated, message: "Use the new initializer or convenience methods like postJSON() instead. Note: GET/DELETE with parameters now use query strings.")
    public init(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) {
        self.method = method
        self.url = url

        // Convert old API to new body format
        if let parameters = parameters {
            if method == .get || method == .delete {
                // For backward compatibility, GET/DELETE with parameters were previously ignored
                // Now they're encoded as query parameters via formParameters
                self.body = .formParameters(parameters)
            } else {
                switch contentType {
                case .json:
                    self.body = .jsonParameters(parameters)
                case .formEncoded:
                    self.body = .formParameters(parameters)
                default:
                    self.body = .formParameters(parameters)
                }
            }
        } else {
            self.body = .none
        }
    }

    /// Creates a GET request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured HTTPRequest
    public static func get(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let body: HTTPRequestBody = parameters.map { .formParameters($0) } ?? .none
        return HTTPRequest(uncheckedMethod: .get, url: url, body: body)
    }

    /// Creates a PUT request with a URL-encoded form body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured HTTPRequest
    public static func putForm(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let body: HTTPRequestBody = parameters.map { .formParameters($0) } ?? .none
        return HTTPRequest(uncheckedMethod: .put, url: url, body: body)
    }

    /// Creates a PUT request with a JSON body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured HTTPRequest
    public static func putJSON(_ url: URL, body: [String: any Sendable]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .put, url: url, body: .jsonParameters(body))
    }

    /// Creates a POST request with a URL-encoded form body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured HTTPRequest
    public static func postForm(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let body: HTTPRequestBody = parameters.map { .formParameters($0) } ?? .none
        return HTTPRequest(uncheckedMethod: .post, url: url, body: body)
    }

    /// Creates a POST request with a JSON body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured HTTPRequest
    public static func postJSON(_ url: URL, body: [String: any Sendable]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .post, url: url, body: .jsonParameters(body))
    }

    /// Creates a DELETE request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured HTTPRequest
    public static func delete(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let body: HTTPRequestBody = parameters.map { .formParameters($0) } ?? .none
        return HTTPRequest(uncheckedMethod: .delete, url: url, body: body)
    }

    /// Creates a basic POST request with no body.
    /// - Parameters:
    ///   - url: The target URL
    /// - Returns: A configured HTTPRequest
    public static func post(_ url: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .post, url: url, body: .none)
    }

    /// Creates a basic PUT request with no body.
    /// - Parameters:
    ///   - url: The target URL
    /// - Returns: A configured HTTPRequest
    public static func put(_ url: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .put, url: url, body: .none)
    }

    /// Creates a basic PATCH request with no body.
    /// - Parameters:
    ///   - url: The target URL
    /// - Returns: A configured HTTPRequest
    public static func patch(_ url: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .patch, url: url, body: .none)
    }

    /// Creates a POST request with a Codable body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured HTTPRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func post<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> HTTPRequest {
        let jsonData = try encoder.encode(body)
        return HTTPRequest(uncheckedMethod: .post, url: url, body: .data(jsonData, contentType: .json))
    }

    /// Creates a PUT request with a Codable body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured HTTPRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func put<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> HTTPRequest {
        let jsonData = try encoder.encode(body)
        return HTTPRequest(uncheckedMethod: .put, url: url, body: .data(jsonData, contentType: .json))
    }

    /// Creates a PATCH request with a URL-encoded form body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured HTTPRequest
    public static func patchForm(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let body: HTTPRequestBody = parameters.map { .formParameters($0) } ?? .none
        return HTTPRequest(uncheckedMethod: .patch, url: url, body: body)
    }

    /// Creates a PATCH request with a JSON body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured HTTPRequest
    public static func patchJSON(_ url: URL, body: [String: any Sendable]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .patch, url: url, body: .jsonParameters(body))
    }

    /// Creates a PATCH request with a Codable body.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured HTTPRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func patch<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> HTTPRequest {
        let jsonData = try encoder.encode(body)
        return HTTPRequest(uncheckedMethod: .patch, url: url, body: .data(jsonData, contentType: .json))
    }

    /// Creates a POST request with multipart form data.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parts: The multipart form parts
    /// - Returns: A configured HTTPRequest
    public static func postMultipart(_ url: URL, parts: [MultipartFormEncoder.Part]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .post, url: url, body: .multipart(parts))
    }

    /// Creates a PUT request with multipart form data.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parts: The multipart form parts
    /// - Returns: A configured HTTPRequest
    public static func putMultipart(_ url: URL, parts: [MultipartFormEncoder.Part]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .put, url: url, body: .multipart(parts))
    }

    /// Creates a PATCH request with multipart form data.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parts: The multipart form parts
    /// - Returns: A configured HTTPRequest
    public static func patchMultipart(_ url: URL, parts: [MultipartFormEncoder.Part]) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .patch, url: url, body: .multipart(parts))
    }

    /// Creates a POST request with raw data and content type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - data: The raw data to send
    ///   - contentType: The uniform type identifier for the data
    /// - Returns: A configured HTTPRequest
    public static func post(_ url: URL, data: Data, contentType: UTType) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .post, url: url, body: .data(data, contentType: contentType))
    }

    /// Creates a PUT request with raw data and content type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - data: The raw data to send
    ///   - contentType: The uniform type identifier for the data
    /// - Returns: A configured HTTPRequest
    public static func put(_ url: URL, data: Data, contentType: UTType) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .put, url: url, body: .data(data, contentType: contentType))
    }

    /// Creates a PATCH request with raw data and content type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - data: The raw data to send
    ///   - contentType: The uniform type identifier for the data
    /// - Returns: A configured HTTPRequest
    public static func patch(_ url: URL, data: Data, contentType: UTType) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .patch, url: url, body: .data(data, contentType: contentType))
    }

    /// Creates a POST request with file data to be streamed from disk.
    /// - Parameters:
    ///   - url: The target URL
    ///   - fileURL: The file URL to stream as the request body
    /// - Returns: A configured HTTPRequest
    public static func postFile(_ url: URL, fileURL: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .post, url: url, body: .fileData(fileURL))
    }

    /// Creates a PUT request with file data to be streamed from disk.
    /// - Parameters:
    ///   - url: The target URL
    ///   - fileURL: The file URL to stream as the request body
    /// - Returns: A configured HTTPRequest
    public static func putFile(_ url: URL, fileURL: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .put, url: url, body: .fileData(fileURL))
    }

    /// Creates a PATCH request with file data to be streamed from disk.
    /// - Parameters:
    ///   - url: The target URL
    ///   - fileURL: The file URL to stream as the request body
    /// - Returns: A configured HTTPRequest
    public static func patchFile(_ url: URL, fileURL: URL) -> HTTPRequest {
        HTTPRequest(uncheckedMethod: .patch, url: url, body: .fileData(fileURL))
    }

    // MARK: - Deprecated Methods

    /// Creates a POST request with parameters.
    /// - Parameters:
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    /// - Returns: A configured HTTPRequest
    @available(*, deprecated, message: "Use postJSON(_:body:) or postForm(_:parameters:) instead")
    public static func post(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        guard let parameters = parameters else {
            return HTTPRequest(uncheckedMethod: .post, url: url)
        }

        switch contentType {
        case .json:
            return postJSON(url, body: parameters)
        case .formEncoded:
            return postForm(url, parameters: parameters)
        default:
            // For backward compatibility, treat as form encoded
            return postForm(url, parameters: parameters)
        }
    }

    /// Creates a PUT request with parameters.
    /// - Parameters:
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    /// - Returns: A configured HTTPRequest
    @available(*, deprecated, message: "Use putJSON(_:body:) or putForm(_:parameters:) instead")
    public static func put(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        guard let parameters = parameters else {
            return HTTPRequest(uncheckedMethod: .put, url: url)
        }

        switch contentType {
        case .json:
            return putJSON(url, body: parameters)
        case .formEncoded:
            return putForm(url, parameters: parameters)
        default:
            // For backward compatibility, treat as form encoded
            return putForm(url, parameters: parameters)
        }
    }

    /// Creates a PATCH request with parameters.
    /// - Parameters:
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    /// - Returns: A configured HTTPRequest
    @available(*, deprecated, message: "Use patchJSON(_:body:) or patchForm(_:parameters:) instead")
    public static func patch(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        guard let parameters = parameters else {
            return HTTPRequest(uncheckedMethod: .patch, url: url)
        }

        switch contentType {
        case .json:
            return patchJSON(url, body: parameters)
        case .formEncoded:
            return patchForm(url, parameters: parameters)
        default:
            // For backward compatibility, treat as form encoded
            return patchForm(url, parameters: parameters)
        }
    }

#if canImport(UIKit)

    /// Adds a JPEG image to the multipart form (iOS/tvOS only).
    /// - Parameters:
    ///   - name: The form field name
    ///   - image: The UIImage to convert to JPEG
    ///   - quality: JPEG compression quality (0.0 to 1.0)
    ///   - filename: Optional filename (defaults to "image.jpeg")
    public mutating func addMultipartJPEG(name: String, image: UIImage, quality: CGFloat, filename: String? = nil) {
        guard let data = image.jpegData(compressionQuality: quality) else {
            log.error("Cannot compress image as JPEG data for parameter \(name) (\(filename ?? ""))")
            return
        }

        let newPart = MultipartFormEncoder.Part.data(data, name: name, type: "image/jpeg", filename: filename ?? "image.jpeg")

        switch body {
        case let .multipart(existingParts):
            body = .multipart(existingParts + [newPart])
        default:
            body = .multipart([newPart])
        }
    }
#endif

    /// Adds a header to this request. Deprecated in favour of directly modifying the ``headers`` dictionary.
    /// - Parameters:
    ///   - name: The header name
    ///   - value: The header value
    @available(*, deprecated, message: "Modify the headers dictionary directly on this request instead.")
    public mutating func addHeader(name: String, value: String) {
        headers[name] = value
    }

    public var description: String {
        "<HTTPRequest \(method) \(url)>"
    }
}
