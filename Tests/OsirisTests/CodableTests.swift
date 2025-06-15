//
//  CodableTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class CodableTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.net")!
    
    // Test models
    struct Person: Codable, Sendable, Equatable {
        let name: String
        let email: String
        let age: Int?
    }
    
    struct APIResponse: Codable, Sendable, Equatable {
        let success: Bool
        let data: Person?
        let message: String?
    }
    
    // MARK: - HTTPRequest Codable Body Tests
    
    func testHTTPRequestWithCodableBody() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let request = HTTPRequest(method: .post, url: baseURL, body: person)
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertNotNil(request.body)
        XCTAssertNil(request.parameters)
    }
    
    func testPostJSONConvenience() throws {
        let person = Person(name: "John Doe", email: "john@example.net", age: 25)
        let request = HTTPRequest.postJSON(baseURL, body: person)
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .json)
        XCTAssertNotNil(request.body)
        XCTAssertNil(request.parameters)
    }
    
    func testPutJSONConvenience() throws {
        let person = Person(name: "John Doe", email: "john@example.net", age: 26)
        let request = HTTPRequest.putJSON(baseURL, body: person)
        
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .json)
        XCTAssertNotNil(request.body)
        XCTAssertNil(request.parameters)
    }
    
    // MARK: - RequestBuilder Codable Encoding Tests
    
    func testRequestBuilderWithCodableBody() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let httpRequest = HTTPRequest.postJSON(baseURL, body: person)
        
        let urlRequest = try RequestBuilder.build(request: httpRequest)
        
        XCTAssertEqual(urlRequest.url, baseURL)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)
        
        // Verify the JSON was encoded correctly
        let decodedPerson = try JSONDecoder().decode(Person.self, from: urlRequest.httpBody!)
        XCTAssertEqual(decodedPerson, person)
    }
    
    func testRequestBuilderPrefersCodableOverParameters() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let params = ["name": "Different Name", "email": "different@example.net"]
        
        let httpRequest = HTTPRequest(
            method: .post,
            url: baseURL,
            contentType: .json,
            parameters: params,
            body: person
        )
        
        let urlRequest = try RequestBuilder.build(request: httpRequest)
        
        // Should use the Codable body, not the parameters
        let decodedPerson = try JSONDecoder().decode(Person.self, from: urlRequest.httpBody!)
        XCTAssertEqual(decodedPerson, person)
        XCTAssertEqual(decodedPerson.name, "Jane Doe") // Not "Different Name"
    }
    
    // MARK: - HTTPResponse Decoding Tests
    
    func testHTTPResponseDecodeSuccess() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let jsonData = try JSONEncoder().encode(person)
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.success(httpURLResponse, jsonData)
        
        let decodedPerson = try response.decode(Person.self)
        XCTAssertEqual(decodedPerson, person)
    }
    
    func testHTTPResponseDecodeFailureCase() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let jsonData = try JSONEncoder().encode(person)
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 400,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.failure(HTTPRequestError.http, httpURLResponse, jsonData)
        
        // Should still be able to decode data from failure responses
        let decodedPerson = try response.decode(Person.self)
        XCTAssertEqual(decodedPerson, person)
    }
    
    func testHTTPResponseDecodeNoData() throws {
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let response = HTTPResponse.success(httpURLResponse, nil)
        
        XCTAssertThrowsError(try response.decode(Person.self)) { error in
            XCTAssertTrue(error is DecodingError)
            if case DecodingError.dataCorrupted(let context) = error {
                XCTAssertEqual(context.debugDescription, "No data found in response")
            } else {
                XCTFail("Expected DecodingError.dataCorrupted")
            }
        }
    }
    
    func testHTTPResponseDecodeInvalidJSON() throws {
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.success(httpURLResponse, invalidJSON)
        
        XCTAssertThrowsError(try response.decode(Person.self)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testHTTPResponseTryDecodeSuccess() throws {
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let jsonData = try JSONEncoder().encode(person)
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.success(httpURLResponse, jsonData)
        
        let decodedPerson = response.tryDecode(Person.self)
        XCTAssertNotNil(decodedPerson)
        XCTAssertEqual(decodedPerson, person)
    }
    
    func testHTTPResponseTryDecodeFailure() throws {
        let invalidJSON = "{ invalid json }".data(using: .utf8)!
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.success(httpURLResponse, invalidJSON)
        
        let decodedPerson = response.tryDecode(Person.self)
        XCTAssertNil(decodedPerson)
    }
    
    func testHTTPResponseTryDecodeNoData() throws {
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        
        let response = HTTPResponse.success(httpURLResponse, nil)
        
        let decodedPerson = response.tryDecode(Person.self)
        XCTAssertNil(decodedPerson)
    }
    
    // MARK: - Custom JSONDecoder Tests
    
    func testHTTPResponseDecodeWithCustomDecoder() throws {
        // Create a Person with an ISO8601 date as a string (for testing custom decoder)
        let apiResponse = APIResponse(
            success: true,
            data: Person(name: "Jane Doe", email: "jane@example.net", age: 30),
            message: "Success"
        )
        
        let jsonData = try JSONEncoder().encode(apiResponse)
        
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let response = HTTPResponse.success(httpURLResponse, jsonData)
        
        // Test with custom decoder (just using default for this test)
        let customDecoder = JSONDecoder()
        let decodedResponse = try response.decode(APIResponse.self, using: customDecoder)
        XCTAssertEqual(decodedResponse, apiResponse)
    }
    
    // MARK: - Integration Tests
    
    func testEndToEndCodableFlow() throws {
        // Create request with Codable body
        let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
        let httpRequest = HTTPRequest.postJSON(baseURL, body: person)
        
        // Build URLRequest
        let urlRequest = try RequestBuilder.build(request: httpRequest)
        
        // Simulate successful response with the same data
        let responseData = urlRequest.httpBody!
        let httpURLResponse = HTTPURLResponse(
            url: baseURL,
            statusCode: 201,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        
        let httpResponse = HTTPResponse.success(httpURLResponse, responseData)
        
        // Decode response
        let decodedPerson = try httpResponse.decode(Person.self)
        XCTAssertEqual(decodedPerson, person)
    }
}