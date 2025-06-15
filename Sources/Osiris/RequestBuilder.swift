//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
import OSLog

private let log = Logger(subsystem: "co.1se.Osiris", category: "RequestBuilder")

/// Errors that can occur when building URLRequest from HTTPRequest.
public enum RequestBuilderError: Error {
    
    /// The form data could not be encoded properly.
    case invalidFormData(HTTPRequest)
}

/// Converts HTTPRequest instances to URLRequest for use with URLSession.
///
/// RequestBuilder handles the encoding of different content types including JSON,
/// form-encoded parameters, and multipart forms. For multipart forms, it encodes
/// everything in memory, so consider using the MultipartFormEncoder directly for
/// large files that should be streamed.
///
/// ## Usage
///
/// ```swift
/// let httpRequest = HTTPRequest.post(
///     URL(string: "https://api.example.net/users")!,
///     contentType: .json,
///     parameters: ["name": "Jane", "email": "jane@example.net"]
/// )
/// 
/// let urlRequest = try RequestBuilder.build(request: httpRequest)
/// let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
///     let httpResponse = HTTPResponse(response: response, data: data, error: error)
///     // Handle response...
/// }
/// ```
public final class RequestBuilder {
    
    /// Converts an HTTPRequest to a URLRequest ready for use with URLSession.
    ///
    /// This method handles encoding of parameters according to the request's method and content type:
    /// - **GET/DELETE**: Parameters are encoded as query string parameters
    /// - `.json`: Parameters are encoded as JSON in the request body (POST/PUT/PATCH)
    /// - `.formEncoded`: Parameters are URL-encoded in the request body (POST/PUT/PATCH)
    /// - `.multipart`: Parts are encoded as multipart/form-data (in memory)
    /// - `.none`: Falls back to form encoding for compatibility
    ///
    /// - Parameter request: The HTTPRequest to convert
    /// - Returns: A URLRequest ready for URLSession
    /// - Throws: `RequestBuilderError.invalidFormData` if form encoding fails, if GET/DELETE
    ///           requests contain multipart parts, or various encoding errors from JSONSerialization
    ///           or MultipartFormEncoder
    ///
    /// - Warning: Multipart requests are encoded entirely in memory. For large files,
    ///            consider using MultipartFormEncoder.encodeFile() directly
    public class func build(request: HTTPRequest) throws -> URLRequest {
        var result = URLRequest(url: request.url)
        result.httpMethod = request.method.string
        
        for (name, value) in request.headers {
            result.addValue(value, forHTTPHeaderField: name)
        }

        // Handle parameters based on HTTP method
        if request.method == .get || request.method == .delete, let params = request.parameters {
            // Validate that GET and DELETE requests don't want request bodies, which we don't support.
            guard request.contentType != .multipart, request.parts.isEmpty else {
                throw RequestBuilderError.invalidFormData(request)
            }
            try encodeQueryParameters(to: &result, parameters: params)
        } else if !request.parts.isEmpty || request.contentType == .multipart {
            if request.contentType != .multipart {
                log.info("Encoding request as multipart, overriding its content type of \(request.contentType)")
            }
            try encodeMultipartContent(to: &result, request: request)
        } else if let body = request.body {
            try encodeCodableBody(to: &result, body: body)
        } else if let params = request.parameters {
            try encodeParameters(to: &result, request: request, parameters: params)
        }

        return result
    }
    
    private class func encodeMultipartContent(to urlRequest: inout URLRequest, request: HTTPRequest) throws {
        let encoder = MultipartFormEncoder()
        let body = try encoder.encodeData(parts: request.parts)
        urlRequest.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
        urlRequest.httpBody = body.data
    }
    
    private class func encodeParameters(to urlRequest: inout URLRequest, request: HTTPRequest, parameters: [String: any Sendable]) throws {
        switch request.contentType {
        case .json:
            try encodeJSONParameters(to: &urlRequest, parameters: parameters)
            
        case .none:
            log.warning("Cannot serialize parameters without a content type, falling back to form encoding")
            fallthrough
        case .formEncoded:
            try encodeFormParameters(to: &urlRequest, request: request, parameters: parameters)
            
        case .multipart:
            try encodeMultipartContent(to: &urlRequest, request: request)
        }
    }
    
    private class func encodeJSONParameters(to urlRequest: inout URLRequest, parameters: [String: any Sendable]) throws {
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
    }
    
    private class func encodeFormParameters(to urlRequest: inout URLRequest, request: HTTPRequest, parameters: [String: any Sendable]) throws {
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        guard let formData = FormEncoder.encode(parameters).data(using: .utf8) else {
            throw RequestBuilderError.invalidFormData(request)
        }
        urlRequest.httpBody = formData
    }
    
    private class func encodeCodableBody(to urlRequest: inout URLRequest, body: any Codable & Sendable) throws {
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(body)
    }
    
    private class func encodeQueryParameters(to urlRequest: inout URLRequest, parameters: [String: any Sendable]) throws {
        guard let url = urlRequest.url else {
            return
        }
        
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let newQueryItems = parameters.compactMap { (key, value) -> URLQueryItem? in
            URLQueryItem(name: key, value: String(describing: value))
        }
        
        if let existingQueryItems = components?.queryItems {
            components?.queryItems = existingQueryItems + newQueryItems
        } else {
            components?.queryItems = newQueryItems
        }
        
        urlRequest.url = components?.url ?? url
    }
}
