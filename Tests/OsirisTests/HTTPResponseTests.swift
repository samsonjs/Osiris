//
//  HTTPResponseTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class HTTPResponseTests: XCTestCase {
    func testSuccessResponse() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        let data = Data("{}".utf8)
        
        let response = HTTPResponse(response: httpResponse, data: data, error: nil)
        
        if case let .success(urlResponse, responseData) = response {
            XCTAssertEqual(urlResponse.statusCode, 200)
            XCTAssertEqual(responseData, data)
        } else {
            XCTFail("Expected success response")
        }
    }
    
    func testFailureResponseWithError() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: error)
        
        if case let .failure(responseError, urlResponse, responseData) = response {
            XCTAssertEqual((responseError as NSError).domain, "test")
            XCTAssertEqual(urlResponse?.statusCode, 200)
            XCTAssertNil(responseData)
        } else {
            XCTFail("Expected failure response")
        }
    }
    
    func testFailureResponseWithHTTPError() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil)!
        let data = Data("Not Found".utf8)
        
        let response = HTTPResponse(response: httpResponse, data: data, error: nil)
        
        if case let .failure(error, urlResponse, responseData) = response {
            XCTAssertTrue(error is HTTPRequestError)
            XCTAssertEqual(urlResponse?.statusCode, 404)
            XCTAssertEqual(responseData, data)
        } else {
            XCTFail("Expected failure response")
        }
    }
    
    func testResponseWithoutHTTPURLResponse() {
        let response = HTTPResponse(response: nil, data: nil, error: nil)
        
        if case let .failure(error, _, _) = response {
            XCTAssertTrue(error is HTTPRequestError)
        } else {
            XCTFail("Expected failure response")
        }
    }
    
    func testDataProperty() {
        let data = Data("test".utf8)
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let successResponse = HTTPResponse(response: httpResponse, data: data, error: nil)
        XCTAssertEqual(successResponse.data, data)
        
        let httpErrorResponse = HTTPURLResponse(url: url, statusCode: 400, httpVersion: nil, headerFields: nil)!
        let failureResponse = HTTPResponse(response: httpErrorResponse, data: data, error: nil)
        XCTAssertEqual(failureResponse.data, data)
    }
    
    func testStatusProperty() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 201, httpVersion: nil, headerFields: nil)!
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
        XCTAssertEqual(response.status, 201)
    }
    
    func testHeadersProperty() {
        let url = URL(string: "https://api.example.net")!
        let headers = ["Content-Type": "application/json", "X-Custom": "value"]
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headers)!
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
        XCTAssertEqual(response.headers["Content-Type"] as? String, "application/json")
        XCTAssertEqual(response.headers["X-Custom"] as? String, "value")
    }
    
    func testBodyStringProperty() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data("Hello, World!".utf8)
        
        let response = HTTPResponse(response: httpResponse, data: data, error: nil)
        XCTAssertEqual(response.bodyString, "Hello, World!")
    }
    
    func testBodyStringPropertyWithNoData() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
        XCTAssertEqual(response.bodyString, "")
    }
    
    func testDictionaryFromJSONProperty() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let json = ["name": "John", "age": 30] as [String: any Sendable]
        let data = try! JSONSerialization.data(withJSONObject: json)
        
        let response = HTTPResponse(response: httpResponse, data: data, error: nil)
        let dictionary = response.dictionaryFromJSON
        
        XCTAssertEqual(dictionary["name"] as? String, "John")
        XCTAssertEqual(dictionary["age"] as? Int, 30)
    }
    
    func testDictionaryFromJSONPropertyWithInvalidJSON() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data("invalid json".utf8)
        
        let response = HTTPResponse(response: httpResponse, data: data, error: nil)
        let dictionary = response.dictionaryFromJSON
        
        XCTAssertTrue(dictionary.isEmpty)
    }
    
    func testDictionaryFromJSONPropertyWithNoData() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
        XCTAssertEqual(response.bodyString, "")
    }
    
    func testDictionaryFromJSONPropertyWithNonDictionaryJSON() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let arrayJSON = try! JSONSerialization.data(withJSONObject: ["item1", "item2", "item3"])
        
        let response = HTTPResponse(response: httpResponse, data: arrayJSON, error: nil)
        let dictionary = response.dictionaryFromJSON
        
        XCTAssertTrue(dictionary.isEmpty)
    }
    
    func testUnderlyingResponseProperty() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 201, httpVersion: "HTTP/1.1", headerFields: ["Server": "nginx"])!
        
        let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
        
        if case let .success(underlyingResponse, _) = response {
            XCTAssertEqual(underlyingResponse.statusCode, 201)
            XCTAssertEqual(underlyingResponse.allHeaderFields["Server"] as? String, "nginx")
        } else {
            XCTFail("Expected success response")
        }
    }
    
    func testResponseStringDescription() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let data = Data("test response".utf8)
        
        let successResponse = HTTPResponse(response: httpResponse, data: data, error: nil)
        let description = String(describing: successResponse)
        XCTAssertTrue(description.contains("success"))
        
        let failureResponse = HTTPResponse(response: httpResponse, data: data, error: HTTPRequestError.http)
        let failureDescription = String(describing: failureResponse)
        XCTAssertTrue(failureDescription.contains("failure"))
    }
    
    func testResponseWithDifferentStatusCodes() {
        let url = URL(string: "https://api.example.net")!
        
        // Test various 2xx success codes
        for statusCode in [200, 201, 202, 204, 206] {
            let httpResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
            
            if case .success = response {
                // Expected
            } else {
                XCTFail("Status code \(statusCode) should be success")
            }
        }
        
        // Test various error status codes  
        for statusCode in [300, 400, 401, 404, 500, 503] {
            let httpResponse = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
            let response = HTTPResponse(response: httpResponse, data: nil, error: nil)
            
            if case .failure = response {
                // Expected
            } else {
                XCTFail("Status code \(statusCode) should be failure")
            }
        }
    }
    
    func testResponseWithBinaryData() {
        let url = URL(string: "https://api.example.net")!
        let httpResponse = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        let binaryData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) // PNG header
        
        let response = HTTPResponse(response: httpResponse, data: binaryData, error: nil)
        
        XCTAssertEqual(response.data, binaryData)
        // bodyString should handle binary data gracefully - it will be empty since this isn't valid UTF-8
        let bodyString = response.bodyString
        XCTAssertTrue(bodyString.isEmpty) // Binary data that isn't valid UTF-8 returns empty string
    }
    
    func testResponseStatusPropertyEdgeCases() {
        // Test with no HTTP response - creates dummy HTTPURLResponse with status 0
        let responseNoHTTP = HTTPResponse(response: nil, data: nil, error: nil)
        XCTAssertEqual(responseNoHTTP.status, 0)
        
        // Test with URLResponse that's not HTTPURLResponse - creates dummy HTTPURLResponse with status 0
        let url = URL(string: "file:///test.txt")!
        let fileResponse = URLResponse(url: url, mimeType: "text/plain", expectedContentLength: 10, textEncodingName: nil)
        let responseNonHTTP = HTTPResponse(response: fileResponse, data: nil, error: nil)
        XCTAssertEqual(responseNonHTTP.status, 0)
    }
}
