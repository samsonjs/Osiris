//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

enum RequestBuilderError: Error {
    case invalidFormData(HTTPRequest)
}

final class RequestBuilder {
    class func build(request: HTTPRequest) throws -> URLRequest {
        assert(!(request.method == .get && request.parameters != nil), "encoding GET params is not yet implemented")
        var result = URLRequest(url: request.url)
        result.httpMethod = request.method.string
        for (name, value) in request.headers {
            result.addValue(value, forHTTPHeaderField: name)
        }
        if let params = request.parameters {
            switch request.contentType {
            case .json:
                result.addValue("application/json", forHTTPHeaderField: "Content-Type")
                result.httpBody = try JSONSerialization.data(withJSONObject: params, options: [])

            case .none:
                // Fall back to form encoding for maximum compatibility.
                assertionFailure("Cannot serialize parameters without a content type")
                fallthrough
            case .formEncoded:
                result.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                guard let formData = FormEncoder.encode(params).data(using: .utf8) else {
                    throw RequestBuilderError.invalidFormData(request)
                }
                result.httpBody = formData

            case .multipart:
                let encoder = MultipartFormEncoder()
                for part in request.parts {
                    encoder.addPart(part)
                }
                let body = encoder.encode()
                result.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
                result.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
                result.httpBody = body.data
            }
        }
        return result
    }
}
