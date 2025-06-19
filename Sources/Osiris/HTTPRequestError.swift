//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// Specific errors for HTTP request processing.
public enum HTTPRequestError: Error, LocalizedError, CustomStringConvertible {

    /// An HTTP error occurred (non-2xx status code).
    case http

    /// An unknown error occurred (typically when URLResponse isn't HTTPURLResponse).
    case unknown

    /// Invalid request body for the HTTP method.
    case invalidRequestBody

    public var errorDescription: String? {
        switch self {
        case .http:
            return "HTTP request failed with non-2xx status code"
        case .unknown:
            return "An unknown error occurred"
        case .invalidRequestBody:
            return "GET and DELETE requests cannot have a body"
        }
    }

    public var failureReason: String? {
        switch self {
        case .http:
            return "The server returned an error status code"
        case .unknown:
            return "An unexpected error occurred during the request"
        case .invalidRequestBody:
            return "The HTTP method does not support a request body"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .http:
            return "Check the server response for error details"
        case .unknown:
            return "Check network connectivity and try again"
        case .invalidRequestBody:
            return "Use query parameters instead of a request body for GET and DELETE requests"
        }
    }

    public var description: String {
        switch self {
        case .http:
            "HTTPRequestError.http"
        case .unknown:
            "HTTPRequestError.unknown"
        case .invalidRequestBody:
            "HTTPRequestError.invalidRequestBody"
        }
    }
}
