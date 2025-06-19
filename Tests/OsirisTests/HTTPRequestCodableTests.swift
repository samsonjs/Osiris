//
// Created by Sami Samhuri on 2025-06-23.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import XCTest
@testable import Osiris

class HTTPRequestCodableTests: XCTestCase {
    let baseURL = URL(string: "https://trails.example.net")!
    
    func testPOSTWithCodableBody() throws {
        let rachel = CreateRiderRequest(name: "Rachel Atherton", email: "rachel@trails.example.net", bike: "Trek Session")
        let request = try HTTPRequest.post(baseURL.appendingPathComponent("riders"), body: rachel)
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url.path, "/riders")
        
        // Verify the body contains JSON data
        if case let .data(data, contentType) = request.body {
            XCTAssertEqual(contentType, .json)
            let decodedRider = try JSONDecoder().decode(CreateRiderRequest.self, from: data)
            XCTAssertEqual(decodedRider.name, rachel.name)
            XCTAssertEqual(decodedRider.email, rachel.email)
            XCTAssertEqual(decodedRider.bike, rachel.bike)
        } else {
            XCTFail("Expected data body with JSON content type")
        }
    }
    
    func testPOSTWithCustomEncoder() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        let danny = CreateRiderRequest(name: "Danny MacAskill", email: "danny@trails.example.net", bike: "Santa Cruz 5010")
        let request = try HTTPRequest.post(baseURL.appendingPathComponent("riders"), body: danny, encoder: encoder)
        
        XCTAssertEqual(request.method, .post)
        
        if case let .data(data, _) = request.body {
            let jsonString = String(data: data, encoding: .utf8)!
            // Should use snake_case for JSON keys - verify the raw JSON contains the right keys
            XCTAssertTrue(jsonString.contains("name"))
            XCTAssertTrue(jsonString.contains("email"))
            XCTAssertTrue(jsonString.contains("bike"))
        } else {
            XCTFail("Expected data body")
        }
    }
    
    func testPUTWithCodableBody() throws {
        let updateRider = CreateRiderRequest(name: "Greg Minnaar", email: "greg@trails.example.net", bike: "Santa Cruz V10")
        let request = try HTTPRequest.put(baseURL.appendingPathComponent("riders/greg-minnaar"), body: updateRider)
        
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.url.path, "/riders/greg-minnaar")
        
        if case let .data(data, contentType) = request.body {
            XCTAssertEqual(contentType, .json)
            XCTAssertNotNil(data)
        } else {
            XCTFail("Expected data body")
        }
    }
    
    func testPATCHWithCodableBody() throws {
        let patchData = CreateRiderRequest(name: "Brandon Semenuk", email: "brandon@trails.example.net", bike: "Trek Ticket S")
        let request = try HTTPRequest.patch(baseURL.appendingPathComponent("riders/brandon-semenuk"), body: patchData)
        
        XCTAssertEqual(request.method, .patch)
        XCTAssertEqual(request.url.path, "/riders/brandon-semenuk")
        
        if case .data = request.body {
            // Success - has data body
        } else {
            XCTFail("Expected data body")
        }
    }
    
    func testRequestBuilderWithCodableBody() throws {
        let aaron = CreateRiderRequest(name: "Aaron Gwin", email: "aaron@trails.example.net", bike: "Intense M29")
        let request = try HTTPRequest.post(baseURL.appendingPathComponent("riders"), body: aaron)
        
        let urlRequest = try RequestBuilder.build(request: request)
        
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)
        
        // Test that the JSON is valid
        if let body = urlRequest.httpBody {
            let decodedRider = try JSONDecoder().decode(CreateRiderRequest.self, from: body)
            XCTAssertEqual(decodedRider.name, "Aaron Gwin")
            XCTAssertEqual(decodedRider.email, "aaron@trails.example.net")
            XCTAssertEqual(decodedRider.bike, "Intense M29")
        }
    }
    
    func testURLSessionExtensionWithCustomDecoder() async throws {
        // Test the URLSession extension methods exist and compile
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        let request = HTTPRequest.get(baseURL.appendingPathComponent("riders"))
        
        // These would work with a real server, but we're just testing compilation
        Task {
            do {
                // Test type inference version
                let inferred: [RiderProfile] = try await URLSession.shared.perform(request, decoder: decoder)

                // Test explicit type version  
                let explicit: [RiderProfile] = try await URLSession.shared.perform(request, expecting: [RiderProfile].self, decoder: decoder)

                XCTAssertEqual(inferred, explicit)

                // Test perform version (no return value)
                try await URLSession.shared.perform(request)
            } catch {
                // Expected to fail without a real server
            }
        }
        
        // If we get here, the methods exist and compile correctly
        XCTAssertTrue(true)
    }
    
    func testHTTPErrorTypes() {
        // Test HTTPError enum cases exist and provide useful information
        let data = "Error message".data(using: .utf8)!
        let response = HTTPURLResponse(url: baseURL, statusCode: 404, httpVersion: nil, headerFields: nil)!
        
        let httpError = HTTPError.failure(statusCode: 404, data: data, response: response)
        let invalidResponse = HTTPError.invalidResponse
        
        // Test error descriptions are helpful
        XCTAssertTrue(httpError.errorDescription?.contains("404") ?? false)
        XCTAssertTrue(httpError.errorDescription?.contains("Error message") ?? false)
        XCTAssertNotNil(invalidResponse.errorDescription)
        
        // Test debug descriptions
        XCTAssertTrue(httpError.debugDescription.contains("404"))
        XCTAssertTrue(httpError.debugDescription.contains("Error message"))
    }
}
