//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "net.samhuri.Osiris", category: "RequestBuilder")

/// Errors that can occur when building URLRequest from ``HTTPRequest``.
public enum RequestBuilderError: Error {

    /// The form data could not be encoded properly.
    case invalidFormData(HTTPRequest)
}

/// Converts ``HTTPRequest`` instances to URLRequest for use with URLSession.
///
/// ``RequestBuilder`` handles the encoding of different content types including JSON,
/// form-encoded parameters, and multipart forms. For multipart forms, it encodes
/// everything in memory, so consider using the ``MultipartFormEncoder`` directly to
/// encode large files to disk for streaming.
///
/// ## Usage
///
/// ```swift
/// let httpRequest = HTTPRequest.postJSON(
///     URL(string: "https://trails.example.net/riders")!,
///     body: ["name": "Trent Reznor", "email": "trent@example.net", "bike": "Santa Cruz Nomad"]
/// )
///
/// let urlRequest = try RequestBuilder.build(request: httpRequest)
/// let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
///     let httpResponse = HTTPResponse(response: response, data: data, error: error)
///     // Handle response...
/// }
/// ```
public final class RequestBuilder {

    /// Converts an ``HTTPRequest`` to a URLRequest ready for use with URLSession.
    ///
    /// This method handles encoding of parameters according to the request's method and content type:
    /// - **GET/DELETE**: Parameters are encoded as query string parameters
    /// - `.json`: Parameters are encoded as JSON in the request body (POST/PUT/PATCH)
    /// - `.formEncoded`: Parameters are URL-encoded in the request body (POST/PUT/PATCH)
    /// - `.multipart`: Parts are encoded as multipart/form-data (in memory)
    /// - `.none`: Falls back to form encoding for compatibility
    ///
    /// - Parameter request: The ``HTTPRequest`` to convert
    /// - Returns: A URLRequest ready for URLSession
    /// - Throws: ``RequestBuilderError/invalidFormData(_:)`` if form encoding fails, if GET/DELETE
    ///           requests contain multipart parts, or various encoding errors from JSONSerialization
    ///           or ``MultipartFormEncoder``
    ///
    /// - Warning: Multipart requests are encoded entirely in memory. For large files,
    ///            consider using ``MultipartFormEncoder/encodeFile(parts:to:)`` to encode to disk first
    public class func build(request: HTTPRequest) throws -> URLRequest {
        var result = URLRequest(url: request.url)
        result.httpMethod = request.method.string

        for (name, value) in request.headers {
            result.addValue(value, forHTTPHeaderField: name)
        }

        // Handle body content based on HTTP method and body type
        switch request.body {
        case .none:
            break
        case let .formParameters(params):
            if request.method == .get || request.method == .delete {
                try encodeQueryParameters(to: &result, parameters: params)
            } else {
                try encodeFormParameters(to: &result, request: request, parameters: params)
            }
        case let .jsonParameters(params):
            if request.method == .get || request.method == .delete {
                try encodeQueryParameters(to: &result, parameters: params)
            } else {
                try encodeJSONParameters(to: &result, parameters: params)
            }
        case let .data(data, contentType):
            result.httpBody = data
            let mimeType = contentType.preferredMIMEType ?? "application/octet-stream"
            if request.headers["Content-Type"] != nil {
                log.warning("Overriding existing Content-Type header with \(mimeType) for data body")
            }
            result.addValue(mimeType, forHTTPHeaderField: "Content-Type")
        case let .multipart(parts):
            try encodeMultipartContent(to: &result, parts: parts)
        case let .fileData(fileURL):
            try encodeFileData(to: &result, fileURL: fileURL)
        }

        return result
    }

    private class func encodeMultipartContent(to urlRequest: inout URLRequest, parts: [MultipartFormEncoder.Part]) throws {
        let encoder = MultipartFormEncoder()
        let body = try encoder.encodeData(parts: parts)

        if urlRequest.value(forHTTPHeaderField: "Content-Type") != nil {
            log.warning("Overriding existing Content-Type header with \(body.contentType) for multipart body")
        }
        if urlRequest.value(forHTTPHeaderField: "Content-Length") != nil {
            log.warning("Overriding existing Content-Length header with \(body.contentLength) for multipart body")
        }

        urlRequest.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
        urlRequest.httpBody = body.data
    }


    private class func encodeJSONParameters(to urlRequest: inout URLRequest, parameters: [String: any Sendable]) throws {
        if urlRequest.value(forHTTPHeaderField: "Content-Type") != nil {
            log.warning("Overriding existing Content-Type header with application/json for JSON body")
        }
        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
    }

    private class func encodeFormParameters(to urlRequest: inout URLRequest, request: HTTPRequest, parameters: [String: any Sendable]) throws {
        if urlRequest.value(forHTTPHeaderField: "Content-Type") != nil {
            log.warning("Overriding existing Content-Type header with application/x-www-form-urlencoded for form body")
        }
        urlRequest.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        guard let formData = FormEncoder.encode(parameters).data(using: .utf8) else {
            throw RequestBuilderError.invalidFormData(request)
        }
        urlRequest.httpBody = formData
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
        } else if !newQueryItems.isEmpty {
            components?.queryItems = newQueryItems
        }

        urlRequest.url = components?.url ?? url
    }

    private class func encodeFileData(to urlRequest: inout URLRequest, fileURL: URL) throws {
        let inputStream = InputStream(url: fileURL)
        urlRequest.httpBodyStream = inputStream

        // Try to get file size for Content-Length header
        if let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = fileAttributes[.size] as? Int {
            if urlRequest.value(forHTTPHeaderField: "Content-Length") != nil {
                log.warning("Overriding existing Content-Length header with \(fileSize) for file data")
            }
            urlRequest.addValue("\(fileSize)", forHTTPHeaderField: "Content-Length")
        }

        // Try to determine Content-Type from file extension
        let fileExtension = fileURL.pathExtension
        if !fileExtension.isEmpty,
           let utType = UTType(filenameExtension: fileExtension),
           let mimeType = utType.preferredMIMEType {
            if urlRequest.value(forHTTPHeaderField: "Content-Type") != nil {
                log.warning("Overriding existing Content-Type header with \(mimeType) for file data")
            }
            urlRequest.addValue(mimeType, forHTTPHeaderField: "Content-Type")
        }
    }
}

