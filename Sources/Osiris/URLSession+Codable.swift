//
// Created by Sami Samhuri on 2025-06-23.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// URLSession extensions for Osiris HTTP requests with automatic JSON decoding.
extension URLSession {
    
    /// Performs an ``HTTPRequest`` and returns decoded JSON response.
    /// - Parameters:
    ///   - request: The ``HTTPRequest`` to perform
    ///   - type: The expected response type
    ///   - decoder: JSONDecoder to use (defaults to standard decoder)
    /// - Returns: Decoded response of the specified type
    /// - Throws: ``HTTPError`` for HTTP errors, URLError for network issues, DecodingError for JSON parsing issues
    public func perform<T: Decodable>(
        _ request: HTTPRequest,
        expecting type: T.Type,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        let urlRequest = try RequestBuilder.build(request: request)
        let (data, response) = try await self.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError.failure(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
        }
        
        do {
            return try decoder.decode(type, from: data)
        } catch let decodingError as DecodingError {
            throw decodingError
        }
    }
    
    /// Performs an ``HTTPRequest`` and returns decoded JSON response with type inference.
    /// - Parameters:
    ///   - request: The ``HTTPRequest`` to perform
    ///   - decoder: JSONDecoder to use (defaults to standard decoder)
    /// - Returns: Decoded response inferred from the return type
    /// - Throws: ``HTTPError`` for HTTP errors, URLError for network issues, DecodingError for JSON parsing issues
    public func perform<T: Decodable>(
        _ request: HTTPRequest,
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        try await perform(request, expecting: T.self, decoder: decoder)
    }
    
    /// Performs an ``HTTPRequest`` expecting no content (e.g., 204 No Content).
    /// - Parameter request: The ``HTTPRequest`` to perform
    /// - Throws: ``HTTPError`` for HTTP errors, URLError for network issues
    public func perform(_ request: HTTPRequest) async throws {
        let urlRequest = try RequestBuilder.build(request: request)
        let (data, response) = try await self.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPError.invalidResponse
        }
        
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw HTTPError.failure(statusCode: httpResponse.statusCode, data: data, response: httpResponse)
        }
    }
}
