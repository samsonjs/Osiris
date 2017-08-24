//
//  Created by Sami Samhuri on 2016-07-30.
//  Copyright © 2016 1 Second Everyday. All rights reserved.
//

import PromiseKit
import UIKit

enum ServiceError: Error {
    case malformedRequest(HTTPRequest)
    case malformedResponse(message: String)
}

enum ServiceEnvironment: String {
    case production
    case staging
    case development

    private static let selectedEnvironmentKey = "ServiceEnvironment:SelectedEnvironment"
    static var selected: ServiceEnvironment {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: selectedEnvironmentKey),
                  let selected = ServiceEnvironment(rawValue: rawValue)
            else {
                return .production
            }
            return selected
        }
        set {
            assert(Thread.isMainThread)
            guard newValue != selected else {
                return
            }
            UserDefaults.standard.set(newValue.rawValue, forKey: selectedEnvironmentKey)
        }
    }

    var baseURL: URL {
        switch self {
        case .production: return URL(string: "https://example.com")!
        case .staging: return URL(string: "https://staging.example.com")!
        case .development: return URL(string: "https://dev.example.com")!
        }
    }
}

final class Service {
    fileprivate var token: String?
    fileprivate var environment: ServiceEnvironment
    fileprivate var urlSession: URLSession

    init(environment: ServiceEnvironment, urlSessionConfig: URLSessionConfiguration? = nil) {
        self.environment = environment
        self.urlSession = URLSession(configuration: .urlSessionConfig ?? .default)
        super.init()
    }

    func reconfigure(environment: ServiceEnvironment, urlSessionConfig: URLSessionConfiguration? = nil) {
        self.environment = environment
        self.urlSession = URLSession(configuration: urlSessionConfig ?? .default)
    }

    // MARK: - Authentication

    func authenticate(token: String) {
        self.token = token
    }

    func deauthenticate() {
        token = nil
    }

    // MARK: - Your service calls here

    // For example... (you probably want a more specific result type unpacked from the response though)
    func signUp(email: String, password: String, avatar: UIImage) -> Promise<HTTPResponse> {
        let parameters = ["email" : email, "password" : password]
        let request = postRequest(path: "/accounts", parameters: parameters)
        request.addMultipartJPEG(name: "avatar", image: avatar, quality: 1)
        return performRequest(request)
    }

    // MARK: - Requests

    fileprivate func deleteRequest(path: String, parameters: [String : Any]? = nil) -> HTTPRequest {
        return newRequest(method: .delete, path: path, parameters: parameters)
    }

    fileprivate func getRequest(path: String) -> HTTPRequest {
        return newRequest(method: .get, path: path)
    }

    fileprivate func patchRequest(path: String, parameters: [String : Any]) -> HTTPRequest {
        return newRequest(method: .patch, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func postJSONRequest(path: String, parameters: [String : Any]) -> HTTPRequest {
        return newRequest(method: .post, path: path, contentType: .json, parameters: parameters)
    }

    fileprivate func postRequest(path: String, parameters: [String : Any]) -> HTTPRequest {
        return newRequest(method: .post, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func putJSONRequest(path: String, parameters: [String : Any]) -> HTTPRequest {
        return newRequest(method: .put, path: path, contentType: .json, parameters: parameters)
    }

    fileprivate func putRequest(path: String, parameters: [String : Any]) -> HTTPRequest {
        return newRequest(method: .put, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func newRequest(method: HTTPMethod, path: String, contentType: HTTPContentType = .none, parameters: [String : Any]? = nil) -> HTTPRequest {
        let url = environment.baseURL.appendingPathComponent(path)
        return newRequest(method: method, url: url, contentType: contentType, parameters: parameters)
    }

    fileprivate func newRequest(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String : Any]? = nil) -> HTTPRequest {
        let request = HTTPRequest(method: method, url: url, contentType: contentType, parameters: parameters)

        // Authorize requests to our service automatically.
        if let token = self.token, url.hasBaseURL(environment.baseURL) {
            authorizeRequest(request, token: token)
        }
        return request
    }

    fileprivate func authorizeRequest(_ request: HTTPRequest, token: String) {
        let encodedCredentials = "api:\(token)".base64
        let basicAuth = "Basic \(encodedCredentials)"
        request.addHeader(name: "Authorization", value: basicAuth)
    }

    func performRequest(_ request: HTTPRequest) -> Promise<HTTPResponse> {
        let urlRequest: URLRequest
        do {
            urlRequest = try RequestBuilder.build(request: request)
        }
        catch {
            log.error("Invalid request \(request): \(error)")
            return Promise(error: ServiceError.malformedRequest(request))
        }
        return Promise { fulfill, reject in
            let start = Date()
            let task = self.urlSession.dataTask(with: urlRequest) { maybeData, maybeResponse, maybeError in
                let response = HTTPResponse(response: maybeResponse, data: maybeData, error: maybeError)
                _ = {
                    let end = Date()
                    let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
                    self.logRequest(request, response: response, duration: duration)
                }()
                fulfill(response)
            }
            task.resume()
        }
    }

    private func scrubParameters(_ parameters: [String : Any], for url: URL) -> [String : Any] {
        return parameters.reduce([:], { params, param in
            var params = params
            let (name, value) = param
            let isBlacklisted = self.isBlacklisted(url: url, paramName: name)
            params[name] = isBlacklisted ? "<secret>" : value
            return params
        })
    }

    private func isBlacklisted(url: URL, paramName: String) -> Bool {
        return paramName.contains("password")
    }

    private func logRequest(_ request: HTTPRequest, response: HTTPResponse, duration: TimeInterval) {
        let method = request.method.string
        let url = request.url
        let type = response.headers["Content-Type"] ?? "no content"
        let seconds = (1000 * duration).rounded() / 1000
        log.verbose("{\(seconds)s} \(method) \(url) -> \(response.status) (\(response.data?.count ?? 0) bytes, \(type))")
    }
}
