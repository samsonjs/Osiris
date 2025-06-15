//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

/// Content types that can be automatically handled by HTTPRequest.
public enum HTTPContentType: Sendable, CustomStringConvertible {

    /// application/x-www-form-urlencoded
    case formEncoded

    /// No specific content type
    case none

    /// application/json
    case json

    /// multipart/form-data (set automatically when parts are added)
    case multipart

    public var description: String {
        switch self {
        case .formEncoded:
            return "application/x-www-form-urlencoded"
        case .none:
            return "none"
        case .json:
            return "application/json"
        case .multipart:
            return "multipart/form-data"
        }
    }
}
