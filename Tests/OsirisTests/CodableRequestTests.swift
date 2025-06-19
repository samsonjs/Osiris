//
// Created by Claude Code on 2025-06-16.
// Copyright © 2025 1 Second Everyday. All rights reserved.
// Released under the terms of the MIT license.
//

import XCTest
@testable import Osiris

// Test models
struct RiderProfile: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
    let bike: String
}

struct CreateRiderRequest: Codable {
    let name: String
    let email: String
    let bike: String
}

class CodableRequestTests: XCTestCase {
    let baseURL = URL(string: "https://trails.example.net")!

    func testCodableRequestGET() {
        let request: CodableRequest<RiderProfile> = .get(baseURL.appending(path: "rider/danny-macaskill"))

        XCTAssertEqual(request.httpRequest.method, HTTPMethod.get)
        XCTAssertEqual(request.httpRequest.url.path, "/rider/danny-macaskill")
        XCTAssertEqual(request.httpRequest.contentType, HTTPContentType.none)
        XCTAssertTrue(request.responseType == RiderProfile.self)
    }

    func testCodableRequestPOSTWithCodableBody() throws {
        let newRider = CreateRiderRequest(name: "Rachel Atherton", email: "rachel@example.net", bike: "Trek Session")
        let request: CodableRequest<RiderProfile> = try .post(
            baseURL.appending(path: "riders"),
            body: newRider
        )

        XCTAssertEqual(request.httpRequest.method, HTTPMethod.post)
        XCTAssertEqual(request.httpRequest.url.path, "/riders")
        XCTAssertEqual(request.httpRequest.contentType, HTTPContentType.custom("application/json"))
        XCTAssertTrue(request.responseType == RiderProfile.self)

        // Verify the body contains JSON data
        if case let .data(data, contentType) = request.httpRequest.body {
            XCTAssertEqual(contentType, .json)
            let decodedUser = try JSONDecoder().decode(CreateRiderRequest.self, from: data)
            XCTAssertEqual(decodedUser.name, newRider.name)
            XCTAssertEqual(decodedUser.email, newRider.email)
        } else {
            XCTFail("Expected data body")
        }
    }

    func testCodableRequestPOSTWithJSONParameters() {
        let parameters = ["name": "John Doe", "email": "john@example.net"]
        let request: CodableRequest<RiderProfile> = .postJSON(
            baseURL.appending(path: "riders"),
            body: parameters
        )

        XCTAssertEqual(request.httpRequest.method, HTTPMethod.post)
        XCTAssertEqual(request.httpRequest.url.path, "/riders")
        XCTAssertEqual(request.httpRequest.contentType, HTTPContentType.json)
        XCTAssertTrue(request.responseType == RiderProfile.self)

        // Verify the body contains parameters
        if case .jsonParameters(let bodyParams) = request.httpRequest.body {
            XCTAssertEqual(bodyParams.count, 2)
        } else {
            XCTFail("Expected jsonParameters body")
        }
    }

    func testCodableRequestPUTWithCodableBody() throws {
        let updateRider = CreateRiderRequest(name: "Greg Minnaar", email: "greg@example.net", bike: "Santa Cruz V10")
        let request: CodableRequest<RiderProfile> = try .put(
            baseURL.appending(path: "riders/greg-minnaar"),
            body: updateRider
        )

        XCTAssertEqual(request.httpRequest.method, HTTPMethod.put)
        XCTAssertEqual(request.httpRequest.url.path, "/riders/greg-minnaar")
        XCTAssertEqual(request.httpRequest.contentType, HTTPContentType.custom("application/json"))
    }

    func testCodableRequestDELETE() {
        let request: CodableRequest<RiderProfile> = .delete(
            baseURL.appending(path: "riders/brandon-semenuk"),
            parameters: ["confirm": "true"]
        )

        XCTAssertEqual(request.httpRequest.method, HTTPMethod.delete)
        XCTAssertEqual(request.httpRequest.url.path, "/riders/brandon-semenuk")
        XCTAssertEqual(request.httpRequest.contentType, HTTPContentType.none)

        // DELETE parameters should be in the body for query string encoding
        if case .formParameters(let bodyParams) = request.httpRequest.body {
            XCTAssertEqual(bodyParams["confirm"] as? String, "true")
        } else {
            XCTFail("Expected formParameters body")
        }
    }

    func testCodableRequestAddingHeader() {
        let request: CodableRequest<RiderProfile> = .get(baseURL)
            .adding(header: "Authorization", value: "Bearer token123")
            .adding(header: "X-API-Version", value: "1.0")

        XCTAssertEqual(request.httpRequest.headers["Authorization"], "Bearer token123")
        XCTAssertEqual(request.httpRequest.headers["X-API-Version"], "1.0")
    }

    func testRequestBuilderWithCodableRequest() throws {
        let request: CodableRequest<RiderProfile> = .get(
            baseURL.appending(path: "rider/danny-macaskill"),
            parameters: ["include": "profile"]
        )

        let urlRequest = try RequestBuilder.build(codableRequest: request)

        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertTrue(urlRequest.url?.query?.contains("include=profile") ?? false)
    }

    func testRequestBuilderWithCodableRequestAndDecoder() throws {
        let newRider = CreateRiderRequest(name: "Aaron Gwin", email: "aaron@example.net", bike: "Intense M29")
        let request: CodableRequest<RiderProfile> = try .post(
            baseURL.appending(path: "riders"),
            body: newRider
        )

        let decoder = JSONDecoder()
        let (urlRequest, decodeResponse) = try RequestBuilder.build(
            codableRequest: request,
            decoder: decoder
        )

        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)

        // Test that the decoder function works
        let sampleResponseData = """
        {"id": 1, "name": "Aaron Gwin", "email": "aaron@example.net", "bike": "Intense M29"}
        """.data(using: .utf8)!

        let decodedResponse = try decodeResponse(sampleResponseData)
        XCTAssertEqual(decodedResponse.id, 1)
        XCTAssertEqual(decodedResponse.name, "Aaron Gwin")
        XCTAssertEqual(decodedResponse.email, "aaron@example.net")
        XCTAssertEqual(decodedResponse.bike, "Intense M29")
    }

    func testCodableRequestDescription() {
        let request: CodableRequest<RiderProfile> = .get(baseURL.appending(path: "rider/danny-macaskill"))
        let description = request.description

        XCTAssertTrue(description.contains("CodableRequest<RiderProfile>"))
        XCTAssertTrue(description.contains("GET"))
        XCTAssertTrue(description.contains("rider/danny-macaskill"))
    }
}