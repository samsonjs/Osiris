//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

enum HTTPMethod: String {
    case delete
    case get
    case patch
    case post
    case put

    var string: String {
        return rawValue.uppercased()
    }
}

enum HTTPContentType {
    case formEncoded
    case none
    case json
    case multipart
}

final class HTTPRequest {
    let method: HTTPMethod
    let url: URL
    private(set) var contentType: HTTPContentType
    let parameters: [String : Any]?
    private(set) var headers: [String : String] = [:]
    private(set) var parts: [MultipartFormEncoder.Part] = []

    init(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String : Any]? = nil) {
        self.method = method
        self.url = url
        self.contentType = contentType
        self.parameters = parameters
    }

    func addHeader(name: String, value: String) {
        headers[name] = value
    }

    func addMultipartJPEG(name: String, image: UIImage, quality: CGFloat, filename: String? = nil) {
        guard let data = UIImageJPEGRepresentation(image, quality) else {
            assertionFailure()
            return
        }
        let part = MultipartFormEncoder.Part(name: name, type: "image/jpeg", encoding: "binary", data: data, filename: filename)
        addPart(part)
    }

    private func addPart(_ part: MultipartFormEncoder.Part) {
        // Convert this request to multipart
        if parts.isEmpty {
            contentType = .multipart
        }
        parts.append(part)
    }
}

enum HTTPRequestError: Error {
    case http
    case unknown
}

enum HTTPResponse {
    case success(HTTPURLResponse, Data?)
    case failure(Error, HTTPURLResponse, Data?)

    init(response maybeResponse: URLResponse?, data: Data?, error: Error?) {
        guard let response = maybeResponse as? HTTPURLResponse else {
            self = .failure(error ?? HTTPRequestError.unknown, HTTPURLResponse(), data)
            return
        }

        if let error = error {
            self = .failure(error, response, data)
        }
        else if response.statusCode >= 200 && response.statusCode < 300 {
            self = .success(response, data)
        }
        else {
            self = .failure(HTTPRequestError.http, response, data)
        }
    }

    var data: Data? {
        switch self {
        case let .success(_, data): return data
        case let .failure(_, _, data): return data
        }
    }

    var underlyingResponse: HTTPURLResponse {
        switch self {
        case let .success(response, _): return response
        case let .failure(_, response, _): return response
        }
    }

    var status: Int {
        return underlyingResponse.statusCode
    }

    var headers: [AnyHashable : Any] {
        return underlyingResponse.allHeaderFields
    }

    var bodyString: String {
        guard let data = self.data else {
            log.warning("No data found on response: \(self)")
            return ""
        }
        guard let string = String(data: data, encoding: .utf8) else {
            log.warning("Data is not UTF8: \(data)")
            return ""
        }
        return string
    }

    var dictionaryFromJSON: [String : Any] {
        guard let data = self.data else {
            log.warning("No data found on response: \(self)")
            return [:]
        }
        do {
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] else {
                if let parsed = try? JSONSerialization.jsonObject(with: data, options: []) {
                    log.error("Failed to parse JSON as dictionary: \(parsed)")
                }
                return [:]
            }
            return dictionary
        }
        catch {
            let json = String(data: data, encoding: .utf8) ?? "<invalid data>"
            log.error("Failed to parse JSON \(json): \(error)")
            return [:]
        }
    }
}
