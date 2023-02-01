//
// Created by Sami Samhuri on 2017-07-28.
// Copyright © 2017 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

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

struct HTTPRequest {
    var method: HTTPMethod
    var url: URL
    var contentType: HTTPContentType
    var parameters: [String : Any]?
    var headers: [String : String] = [:]
    var parts: [MultipartFormEncoder.Part] = [] {
        didSet {
            if !parts.isEmpty { contentType = .multipart }
        }
    }

    init(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String : Any]? = nil) {
        self.method = method
        self.url = url
        self.contentType = contentType
        self.parameters = parameters
    }

    static func get(_ url: URL, contentType: HTTPContentType = .none) -> HTTPRequest {
        HTTPRequest(method: .get, url: url, contentType: contentType)
    }

    static func put(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: Any]? = nil) -> HTTPRequest {
        HTTPRequest(method: .put, url: url, contentType: contentType, parameters: parameters)
    }

    static func post(_ url: URL, contentType: HTTPContentType = .none, parameters: [String: Any]? = nil) -> HTTPRequest {
        HTTPRequest(method: .post, url: url, contentType: contentType, parameters: parameters)
    }

    static func delete(_ url: URL, contentType: HTTPContentType = .none) -> HTTPRequest {
        HTTPRequest(method: .delete, url: url, contentType: contentType)
    }

#if canImport(UIKit)
    mutating func addMultipartJPEG(name: String, image: UIImage, quality: CGFloat, filename: String? = nil) {
        guard let data = image.jpegData(compressionQuality: quality) else {
            assertionFailure()
            return
        }
        parts.append(
            .data(data, name: name, type: "image/jpeg", filename: filename ?? "image.jpeg")
        )
    }
#endif
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
            NSLog("[WARN] No data found on response: \(self)")
            return ""
        }
        guard let string = String(data: data, encoding: .utf8) else {
            NSLog("[WARN] Data is not UTF8: \(data)")
            return ""
        }
        return string
    }

    var dictionaryFromJSON: [String : Any] {
        guard let data = self.data else {
            NSLog("[WARN] No data found on response: \(self)")
            return [:]
        }
        do {
            guard let dictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] else {
                if let parsed = try? JSONSerialization.jsonObject(with: data, options: []) {
                    NSLog("[ERROR] Failed to parse JSON as dictionary: \(parsed)")
                }
                return [:]
            }
            return dictionary
        }
        catch {
            let json = String(data: data, encoding: .utf8) ?? "<invalid data>"
            NSLog("[ERROR] Failed to parse JSON \(json): \(error)")
            return [:]
        }
    }
}
