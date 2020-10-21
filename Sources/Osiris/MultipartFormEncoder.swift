//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify,
// merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to the following
// conditions:
//
// The above copyright notice and this permission notice shall be included in all copies
// or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
// PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
// HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
// CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
// OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

import Foundation

extension MultipartFormEncoder {
    struct Body {
        let contentType: String
        let data: Data

        var contentLength: Int {
            data.count
        }
    }

    struct Part {
        enum Content {
            case text(String)
            case binary(Data, type: String, filename: String)
        }

        let name: String
        let content: Content

        static func text(name: String, value: String) -> Part {
            Part(name: name, content: .text(value))
        }

        static func binary(name: String, data: Data, type: String, filename: String) -> Part {
            Part(name: name, content: .binary(data, type: type, filename: filename))
        }
    }
}

final class MultipartFormEncoder {
    let boundary: String

    init(boundary: String? = nil) {
        self.boundary = boundary ?? "LifeIsMadeOfSeconds-\(UUID().uuidString)"
    }

    func encode(parts: [Part]) -> Body {
        var bodyData = Data()
        for part in parts {
            // Header
            bodyData.append(Data("--\(boundary)\r\n".utf8))
            switch part.content {
            case .text:
                bodyData.append(Data("Content-Disposition: form-data; name=\"\(part.name)\"\r\n".utf8))

            case let .binary(data, type, filename):
                bodyData.append(Data("Content-Disposition: form-data; name=\"\(part.name)\"; filename=\"\(filename)\"\r\n".utf8))
                bodyData.append(Data("Content-Type: \(type)\r\n".utf8))
                bodyData.append(Data("Content-Length: \(data.count)\r\n".utf8))
            }
            bodyData.append(Data("\r\n".utf8))

            // Body
            switch part.content {
            case let .text(string):
                bodyData.append(Data(string.utf8))

            case let .binary(data, _, _):
                bodyData.append(data)
            }
            bodyData.append(Data("\r\n".utf8))
        }

        // Footer
        bodyData.append(Data("--\(boundary)--".utf8))

        return Body(contentType: "multipart/form-data; boundary=\"\(boundary)\"", data: bodyData)
    }
}
