//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
import OSLog

#if canImport(UIKit)
import UIKit
#endif

private let log = Logger(subsystem: "co.1se.Osiris", category: "HTTPRequest")

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
/// // POST with JSON parameters
/// let jsonRequest = HTTPRequest.post(
///     URL(string: "https://api.example.net/users")!,
///     contentType: .json,
///     parameters: ["name": "Jane", "email": "jane@example.net"]
/// )
///
/// // DELETE with query parameters
/// let deleteRequest = HTTPRequest.delete(
///     URL(string: "https://api.example.net/users/123")!,
///     parameters: ["confirm": "true"]
/// )
///
/// // Multipart form with file upload
/// var multipartRequest = HTTPRequest.post(URL(string: "https://api.example.net/upload")!)
/// multipartRequest.parts = [
///     .text("Jane Doe", name: "name"),
///     .data(imageData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg")
/// ]
/// ```
public struct HTTPRequest: Sendable, CustomStringConvertible {

    /// The HTTP method for this request.
    public var method: HTTPMethod

    /// The target URL for this request.
    public var url: URL

    /// The content type for the request body.
    public var contentType: HTTPContentType

    /// Parameters to be encoded according to the content type.
    public var parameters: [String: any Sendable]?

    /// Additional HTTP headers for the request.
    public var headers: [String: String] = [:]

    /// Multipart form parts (automatically sets contentType to .multipart when non-empty).
    public var parts: [MultipartFormEncoder.Part] = [] {
        didSet {
            if !parts.isEmpty { contentType = .multipart }
        }
    }

    /// Creates a new HTTP request.
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    public init(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) {
        self.method = method
        self.url = url
        self.contentType = contentType
        self.parameters = parameters
    }

    /// Creates a GET request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured HTTPRequest
    public static func get(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        HTTPRequest(method: .get, url: url, contentType: .none, parameters: parameters)
    }

    /// Creates a PUT request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    /// - Returns: A configured HTTPRequest
    public static func put(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        HTTPRequest(method: .put, url: url, contentType: contentType, parameters: parameters)
    }

    /// Creates a POST request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - contentType: The content type for encoding parameters
    ///   - parameters: Optional parameters to include in the request body
    /// - Returns: A configured HTTPRequest
    public static func post(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        HTTPRequest(method: .post, url: url, contentType: contentType, parameters: parameters)
    }

    /// Creates a DELETE request.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured HTTPRequest
    public static func delete(_ url: URL, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        HTTPRequest(method: .delete, url: url, contentType: .none, parameters: parameters)
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
        parts.append(
            .data(data, name: name, type: "image/jpeg", filename: filename ?? "image.jpeg")
        )
    }
#endif

    /// Adds a header to this request.
    /// - Parameters:
    ///   - name: The header name
    ///   - value: The header value
    public mutating func addHeader(name: String, value: String) {
        headers[name] = value
    }

    public var description: String {
        "<HTTPRequest \(method) \(url)>"
    }
}
