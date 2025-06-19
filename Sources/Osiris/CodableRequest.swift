//
// Created by Sami Samhuri on 2025-06-16.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// A type-safe HTTP request that includes response type information.
///
/// CodableRequest wraps an HTTPRequest and adds compile-time type safety for JSON responses.
/// It provides convenient factory methods for creating requests with Codable bodies and
/// automatic JSON encoding/decoding.
///
/// ## Usage
///
/// ```swift
/// // GET request expecting RiderProfile
/// let getRequest: CodableRequest<RiderProfile> = .get(
///     URL(string: "https://trails.example.net/rider/greg-minnaar")!
/// )
///
/// // POST request with Codable body expecting CreateRiderResponse
/// let newRider = CreateRiderRequest(name: "Danny MacAskill", email: "danny@example.net", bike: "Santa Cruz 5010")
/// let postRequest: CodableRequest<CreateRiderResponse> = try .post(
///     URL(string: "https://trails.example.net/riders")!,
///     body: newRider
/// )
/// ```
public struct CodableRequest<Response: Decodable>: Sendable {

    /// The underlying HTTP request.
    public let httpRequest: HTTPRequest

    /// The expected response type (for compile-time type safety).
    public let responseType: Response.Type

    /// Creates a new CodableRequest.
    /// - Parameters:
    ///   - httpRequest: The underlying HTTP request
    ///   - responseType: The expected response type
    public init(_ httpRequest: HTTPRequest, responseType: Response.Type = Response.self) {
        self.httpRequest = httpRequest
        self.responseType = responseType
    }

    /// Creates a GET request expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured CodableRequest
    public static func get(_ url: URL, parameters: [String: any Sendable]? = nil) -> CodableRequest<Response> {
        CodableRequest(.get(url, parameters: parameters))
    }

    /// Creates a POST request with a URL-encoded form body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured CodableRequest
    public static func postForm(_ url: URL, parameters: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.postForm(url, parameters: parameters))
    }

    /// Creates a POST request with a JSON body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured CodableRequest
    public static func postJSON(_ url: URL, body: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.postJSON(url, body: body))
    }

    /// Creates a POST request with a Codable body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured CodableRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func post<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> CodableRequest<Response> {
        try CodableRequest(.post(url, body: body, encoder: encoder))
    }

    /// Creates a PUT request with a URL-encoded form body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured CodableRequest
    public static func putForm(_ url: URL, parameters: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.putForm(url, parameters: parameters))
    }

    /// Creates a PUT request with a JSON body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured CodableRequest
    public static func putJSON(_ url: URL, body: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.putJSON(url, body: body))
    }

    /// Creates a PUT request with a Codable body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured CodableRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func put<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> CodableRequest<Response> {
        try CodableRequest(.put(url, body: body, encoder: encoder))
    }

    /// Creates a PATCH request with a URL-encoded form body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Parameters to encode as URL-encoded form body
    /// - Returns: A configured CodableRequest
    public static func patchForm(_ url: URL, parameters: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.patchForm(url, parameters: parameters))
    }

    /// Creates a PATCH request with a JSON body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: Dictionary to encode as JSON body
    /// - Returns: A configured CodableRequest
    public static func patchJSON(_ url: URL, body: [String: any Sendable]) -> CodableRequest<Response> {
        CodableRequest(.patchJSON(url, body: body))
    }

    /// Creates a PATCH request with a Codable body expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - body: The Codable object to encode as JSON
    ///   - encoder: The JSONEncoder to use (defaults to standard encoder)
    /// - Returns: A configured CodableRequest
    /// - Throws: EncodingError if the body cannot be encoded
    public static func patch<T: Codable>(_ url: URL, body: T, encoder: JSONEncoder = JSONEncoder()) throws -> CodableRequest<Response> {
        try CodableRequest(.patch(url, body: body, encoder: encoder))
    }

    /// Creates a DELETE request expecting the specified response type.
    /// - Parameters:
    ///   - url: The target URL
    ///   - parameters: Optional parameters to include as query string
    /// - Returns: A configured CodableRequest
    public static func delete(_ url: URL, parameters: [String: any Sendable]? = nil) -> CodableRequest<Response> {
        CodableRequest(.delete(url, parameters: parameters))
    }

    /// Adds a header to the underlying HTTP request.
    /// - Parameters:
    ///   - name: The header name
    ///   - value: The header value
    /// - Returns: A new CodableRequest with the added header
    public func adding(header name: String, value: String) -> CodableRequest<Response> {
        var modifiedRequest = httpRequest
        modifiedRequest.addHeader(name: name, value: value)
        return CodableRequest(modifiedRequest)
    }
}

extension CodableRequest: CustomStringConvertible {
    public var description: String {
        "<CodableRequest<\(Response.self)> \(httpRequest.method) \(httpRequest.url)>"
    }
}
