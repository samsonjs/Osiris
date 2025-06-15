//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
import OSLog

private let log = Logger(subsystem: "co.1se.Osiris", category: "HTTPResponse")

/// A response from an HTTP request that simplifies URLSession's completion handler parameters.
///
/// HTTPResponse consolidates URLSession's three optional parameters (URLResponse?, Data?, Error?)
/// into a single enum that clearly indicates success or failure. Success cases include 2xx status
/// codes, while all other status codes and network errors are treated as failures.
///
/// ## Usage
///
/// ```swift
/// let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
///     let httpResponse = HTTPResponse(response: response, data: data, error: error)
///     
///     switch httpResponse {
///     case .success(let httpURLResponse, let data):
///         print("Success: \(httpURLResponse.statusCode)")
///         // Handle successful response
///     case .failure(let error, let httpURLResponse, let data):
///         print("Failed: \(error)")
///         // Handle error response
///     }
/// }
/// ```
public enum HTTPResponse: CustomStringConvertible {
    
    /// A successful response (2xx status code) with the HTTP response and optional body data.
    case success(HTTPURLResponse, Data?)
    
    /// A failed response with the error, optional HTTP response, and optional body data.
    case failure(Error, HTTPURLResponse?, Data?)

    /// Creates an HTTPResponse from URLSession completion handler parameters.
    /// - Parameters:
    ///   - maybeResponse: The URLResponse from URLSession (may be nil)
    ///   - data: The response body data (may be nil)
    ///   - error: Any error that occurred (may be nil)
    public init(response maybeResponse: URLResponse?, data: Data?, error: Error?) {
        guard let response = maybeResponse as? HTTPURLResponse else {
            self = .failure(error ?? HTTPRequestError.unknown, nil, data)
            return
        }

        if let error = error {
            self = .failure(error, response, data)
        }
        else if response.statusCode >= 200 && response.statusCode < 300 {
            self = .success(response, data)
        }
        else {
            self = .failure(HTTPRequestError.http, response, data)
        }
    }

    /// The response body data, available for both success and failure cases.
    public var data: Data? {
        switch self {
        case let .success(_, data): return data
        case let .failure(_, _, data): return data
        }
    }

    /// The underlying HTTPURLResponse for direct access to response properties.
    /// Returns nil when the response wasn't an HTTPURLResponse.
    public var underlyingResponse: HTTPURLResponse? {
        switch self {
        case let .success(response, _): return response
        case let .failure(_, response, _): return response
        }
    }

    /// The HTTP status code returned by the server, or 0 if the request failed completely.
    public var status: Int {
        underlyingResponse?.statusCode ?? 0
    }

    /// All HTTP headers returned by the server.
    public var headers: [AnyHashable : Any] {
        underlyingResponse?.allHeaderFields ?? [:]
    }

    /// The response body decoded as a UTF-8 string.
    /// Returns an empty string if there's no data or if decoding fails.
    public var bodyString: String {
        guard let data = self.data else {
            log.warning("No data found on response: \(String(describing: self))")
            return ""
        }
        guard let string = String(data: data, encoding: .utf8) else {
            log.warning("Data is not UTF8: \(data.count) bytes")
            return ""
        }
        return string
    }

    /// The response body decoded as a JSON dictionary.
    /// Returns an empty dictionary if there's no data, if JSON parsing fails,
    /// or if the JSON is not a dictionary.
    public var dictionaryFromJSON: [String: any Sendable] {
        guard let data = self.data else {
            log.warning("No data found on response: \(String(describing: self))")
            return [:]
        }
        do {
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String: any Sendable] else {
                if let parsed = try? JSONSerialization.jsonObject(with: data, options: []) {
                    log.error("Failed to parse JSON as dictionary: \(String(describing: parsed))")
                }
                return [:]
            }
            return dictionary
        }
        catch {
            let json = String(data: data, encoding: .utf8) ?? "<invalid data>"
            log.error("Failed to parse JSON \(json): \(error)")
            return [:]
        }
    }
    
    public var description: String {
        switch self {
        case let .success(response, data):
            let dataSize = data?.count ?? 0
            return "<HTTPResponse.success status=\(response.statusCode) size=\(dataSize)>"
        case let .failure(error, response, data):
            let status = response?.statusCode ?? 0
            let dataSize = data?.count ?? 0
            return "<HTTPResponse.failure error=\(error) status=\(status) size=\(dataSize)>"
        }
    }
    
    /// Decodes the response body as a Codable type using JSONDecoder.
    /// - Parameters:
    ///   - type: The Codable type to decode to
    ///   - decoder: Optional JSONDecoder to use (defaults to a new instance)
    /// - Returns: The decoded object
    /// - Throws: DecodingError if decoding fails, or various other errors
    public func decode<T: Codable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) throws -> T {
        guard let data = self.data else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "No data found in response")
            )
        }
        return try decoder.decode(type, from: data)
    }
    
    /// Attempts to decode the response body as a Codable type, returning nil on failure.
    /// - Parameters:
    ///   - type: The Codable type to decode to
    ///   - decoder: Optional JSONDecoder to use (defaults to a new instance)
    /// - Returns: The decoded object, or nil if decoding fails
    public func tryDecode<T: Codable>(_ type: T.Type, using decoder: JSONDecoder = JSONDecoder()) -> T? {
        do {
            return try decode(type, using: decoder)
        } catch {
            log.warning("Failed to decode response as \(String(describing: type)): \(error)")
            return nil
        }
    }
}
