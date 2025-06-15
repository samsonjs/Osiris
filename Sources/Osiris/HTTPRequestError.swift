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

    public var errorDescription: String? {
        switch self {
        case .http:
            return "HTTP request failed with non-2xx status code"
        case .unknown:
            return "An unknown error occurred"
        }
    }

    public var failureReason: String? {
        switch self {
        case .http:
            return "The server returned an error status code"
        case .unknown:
            return "An unexpected error occurred during the request"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .http:
            return "Check the server response for error details"
        case .unknown:
            return "Check network connectivity and try again"
        }
    }

    public var description: String {
        switch self {
        case .http:
            "HTTPRequestError.http"
        case .unknown:
            "HTTPRequestError.unknown"
        }
    }
}
