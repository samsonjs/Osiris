//
// Created by Sami Samhuri on 2025-06-23.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// Errors that can occur during HTTP operations, outside of the network layer which is already covered by `URLError`.
public enum HTTPError: Error {
    /// The server returned a non-success HTTP status code.
    case failure(statusCode: Int, data: Data, response: HTTPURLResponse)
    
    /// The response was not a valid HTTP response.
    case invalidResponse
}

private extension String {
    func truncated(to maxCharacters: Int = 50) -> String {
        count < 50 ? self : "\(prefix(maxCharacters))..."
    }
}

extension HTTPError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .failure(statusCode, data, _):
            let bodyString = String(data: data, encoding: .utf8) ?? "<non-UTF8 data>"
            return "HTTP \(statusCode) error. Response body: \(bodyString.truncated())"
        case .invalidResponse:
            return "Invalid HTTP response"
        }
    }
}

extension HTTPError: CustomDebugStringConvertible {
    public var debugDescription: String {
        switch self {
        case let .failure(statusCode, data, response):
            let bodyString = String(data: data, encoding: .utf8) ?? "<\(data.count) bytes of non-UTF8 data>"
            return """
            HTTPError: \(statusCode) \(HTTPURLResponse.localizedString(forStatusCode: statusCode))
            URL: \(response.url?.absoluteString ?? "nil")
            Body: \(bodyString.truncated())
            """
        case .invalidResponse:
            return "HTTPError: Invalid HTTP response"
        }
    }
}
