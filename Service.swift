//
//  Created by Sami Samhuri on 2016-07-30.
//  Copyright © 2016 1 Second Everyday. All rights reserved.
//
//  This file shows how you can actually use Osiris with URLSession.
//

import Foundation
import OSLog
import UIKit

private let log = Logger(subsystem: "co.1se.Osiris", category: "Service")

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
        case .production: return URL(string: "https://example.net")!
        case .staging: return URL(string: "https://staging.example.net")!
        case .development: return URL(string: "https://dev.example.net")!
        }
    }
}

final class Service {
    fileprivate var token: String?
    fileprivate var environment: ServiceEnvironment
    fileprivate var urlSession: URLSession

    init(environment: ServiceEnvironment, urlSessionConfig: URLSessionConfiguration? = nil) {
        self.environment = environment
        self.urlSession = URLSession(configuration: urlSessionConfig ?? .default)
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
    func signUp(email: String, password: String, avatar: UIImage) async throws -> HTTPResponse {
        let parameters = ["email" : email, "password" : password]
        let url = environment.baseURL.appendingPathComponent("accounts")
        var request = HTTPRequest.post(url, contentType: .formEncoded, parameters: parameters)
        request.addMultipartJPEG(name: "avatar", image: avatar, quality: 1)
        return try await performRequest(request)
    }

    // MARK: - Requests

    fileprivate func deleteRequest(path: String, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        return newRequest(method: .delete, path: path, parameters: parameters)
    }

    fileprivate func getRequest(path: String) -> HTTPRequest {
        return newRequest(method: .get, path: path)
    }

    fileprivate func patchRequest(path: String, parameters: [String: any Sendable]) -> HTTPRequest {
        return newRequest(method: .patch, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func postJSONRequest(path: String, parameters: [String: any Sendable]) -> HTTPRequest {
        return newRequest(method: .post, path: path, contentType: .json, parameters: parameters)
    }

    fileprivate func postRequest(path: String, parameters: [String: any Sendable]) -> HTTPRequest {
        return newRequest(method: .post, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func putJSONRequest(path: String, parameters: [String: any Sendable]) -> HTTPRequest {
        return newRequest(method: .put, path: path, contentType: .json, parameters: parameters)
    }

    fileprivate func putRequest(path: String, parameters: [String: any Sendable]) -> HTTPRequest {
        return newRequest(method: .put, path: path, contentType: .formEncoded, parameters: parameters)
    }

    fileprivate func newRequest(method: HTTPMethod, path: String, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
        let url = environment.baseURL.appendingPathComponent(path)
        return newRequest(method: method, url: url, contentType: contentType, parameters: parameters)
    }

    fileprivate func newRequest(method: HTTPMethod, url: URL, contentType: HTTPContentType = .none, parameters: [String: any Sendable]? = nil) -> HTTPRequest {
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

    func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest: URLRequest
        do {
            urlRequest = try RequestBuilder.build(request: request)
        }
        catch {
            log.error("Invalid request \(request): \(error)")
            throw ServiceError.malformedRequest(request)
        }
        
        let start = Date()
        let (data, response) = try await urlSession.data(for: urlRequest)
        let httpResponse = HTTPResponse(response: response, data: data, error: nil)
        
        let end = Date()
        let duration = end.timeIntervalSince1970 - start.timeIntervalSince1970
        logRequest(request, response: httpResponse, duration: duration)
        
        return httpResponse
    }

    private func scrubParameters(_ parameters: [String: any Sendable], for url: URL) -> [String: any Sendable] {
        return parameters.reduce([:], { params, param in
            var params = params
            let (name, value) = param
            let isSensitive = self.isSensitive(url: url, paramName: name)
            params[name] = isSensitive ? "<secret>" : value
            return params
        })
    }

    private func isSensitive(url: URL, paramName: String) -> Bool {
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
