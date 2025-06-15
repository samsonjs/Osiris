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
    /// This method handles encoding of parameters according to the request's content type:
    /// - `.json`: Parameters are encoded as JSON in the request body
    /// - `.formEncoded`: Parameters are URL-encoded in the request body  
    /// - `.multipart`: Parts are encoded as multipart/form-data (in memory)
    /// - `.none`: Falls back to form encoding for compatibility
    ///
    /// - Parameter request: The HTTPRequest to convert
    /// - Returns: A URLRequest ready for URLSession
    /// - Throws: `RequestBuilderError.invalidFormData` if form encoding fails,
    ///           or various encoding errors from JSONSerialization or MultipartFormEncoder
    ///
    /// - Note: GET and DELETE requests with parameters are not currently supported
    /// - Warning: Multipart requests are encoded entirely in memory. For large files,
    ///            consider using MultipartFormEncoder.encodeFile() directly
    public class func build(request: HTTPRequest) throws -> URLRequest {
        assert(!(request.method == .get && request.parameters != nil), "encoding GET params is not yet implemented")
        assert(!(request.method == .delete && request.parameters != nil), "encoding DELETE params is not yet implemented")
        
        var result = URLRequest(url: request.url)
        result.httpMethod = request.method.string
        
        for (name, value) in request.headers {
            result.addValue(value, forHTTPHeaderField: name)
        }

        // When parts are provided then override to be multipart regardless of the content type.
        if !request.parts.isEmpty || request.contentType == .multipart {
            if request.contentType != .multipart {
                log.info("Encoding request as multipart, overriding its content type of \(request.contentType)")
            }
            try encodeMultipartContent(to: &result, request: request)
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
}
