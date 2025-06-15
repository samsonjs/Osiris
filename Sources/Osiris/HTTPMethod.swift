//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// HTTP methods supported by HTTPRequest.
public enum HTTPMethod: String, Sendable, CustomStringConvertible {
    case delete
    case get
    case patch
    case post
    case put

    /// The uppercased string representation of the HTTP method.
    var string: String {
        rawValue.uppercased()
    }

    public var description: String {
        string
    }
}
