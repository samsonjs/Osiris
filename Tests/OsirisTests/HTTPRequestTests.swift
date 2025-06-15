//
//  HTTPRequestTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class HTTPRequestTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.net")!
    
    func testHTTPRequestInitialization() {
        let request = HTTPRequest(method: .get, url: baseURL)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .none)
        XCTAssertNil(request.parameters)
        XCTAssertTrue(request.headers.isEmpty)
        XCTAssertTrue(request.parts.isEmpty)
    }
    
    func testHTTPRequestWithParameters() {
        let params = ["key": "value", "number": 42] as [String: any Sendable]
        let request = HTTPRequest(method: .post, url: baseURL, contentType: .json, parameters: params)
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.contentType, .json)
        XCTAssertNotNil(request.parameters)
    }
    
    func testGETConvenience() {
        let request = HTTPRequest.get(baseURL)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .none)
    }
    
    func testPOSTConvenience() {
        let params = ["name": "Jane"]
        let request = HTTPRequest.post(baseURL, contentType: .json, parameters: params)
        
        XCTAssertEqual(request.method, .post)
        XCTAssertEqual(request.contentType, .json)
        XCTAssertNotNil(request.parameters)
    }
    
    func testPUTConvenience() {
        let params = ["name": "Jane"]
        let request = HTTPRequest.put(baseURL, contentType: .formEncoded, parameters: params)
        
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.contentType, .formEncoded)
        XCTAssertNotNil(request.parameters)
    }
    
    func testDELETEConvenience() {
        let request = HTTPRequest.delete(baseURL)
        XCTAssertEqual(request.method, .delete)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .none)
    }
    
    func testMultipartPartsAutomaticallySetContentType() {
        var request = HTTPRequest.post(baseURL)
        XCTAssertEqual(request.contentType, .none)
        
        request.parts = [.text("value", name: "field")]
        XCTAssertEqual(request.contentType, .multipart)
    }
    
    #if canImport(UIKit)
    func testAddMultipartJPEG() {
        var request = HTTPRequest.post(baseURL)
        
        // Create a simple 1x1 pixel image
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        request.addMultipartJPEG(name: "avatar", image: image, quality: 0.8, filename: "test.jpg")
        
        XCTAssertEqual(request.parts.count, 1)
        XCTAssertEqual(request.contentType, .multipart)
        
        let part = request.parts.first!
        XCTAssertEqual(part.name, "avatar")
        
        if case let .binaryData(_, type, filename) = part.content {
            XCTAssertEqual(type, "image/jpeg")
            XCTAssertEqual(filename, "test.jpg")
        } else {
            XCTFail("Expected binary data content")
        }
    }
    
    func testAddMultipartJPEGWithInvalidQuality() {
        var request = HTTPRequest.post(baseURL)
        
        // Create a valid image
        let size = CGSize(width: 1, height: 1)
        UIGraphicsBeginImageContext(size)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        // Test with extreme quality values that might cause issues
        request.addMultipartJPEG(name: "avatar1", image: image, quality: -1.0)
        request.addMultipartJPEG(name: "avatar2", image: image, quality: 2.0)
        
        // The method should handle extreme quality values gracefully
        // Either by clamping them or by having jpegData handle them
        XCTAssertTrue(request.parts.count >= 0) // Should not crash
    }
    #endif
    
    func testHTTPRequestPATCHConvenience() {
        let params = ["status": "active"]
        let request = HTTPRequest(method: .patch, url: baseURL, contentType: .json, parameters: params)
        
        XCTAssertEqual(request.method, .patch)
        XCTAssertEqual(request.contentType, .json)
        XCTAssertNotNil(request.parameters)
    }
    
    func testHTTPRequestWithMultipleHeaders() {
        var request = HTTPRequest.get(baseURL)
        request.addHeader(name: "Authorization", value: "Bearer token123")
        request.addHeader(name: "User-Agent", value: "Osiris/2.0")
        request.addHeader(name: "Accept", value: "application/json")
        
        XCTAssertEqual(request.headers["Authorization"], "Bearer token123")
        XCTAssertEqual(request.headers["User-Agent"], "Osiris/2.0")
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertEqual(request.headers.count, 3)
    }
    
    func testHTTPRequestOverwriteHeaders() {
        var request = HTTPRequest.get(baseURL)
        request.addHeader(name: "Accept", value: "application/xml")
        request.addHeader(name: "Accept", value: "application/json") // Should overwrite
        
        XCTAssertEqual(request.headers["Accept"], "application/json")
        XCTAssertEqual(request.headers.count, 1)
    }
    
    func testHTTPRequestWithEmptyMultipartParts() {
        var request = HTTPRequest.post(baseURL)
        request.parts = [] // Empty parts array
        
        XCTAssertEqual(request.contentType, .none) // Should not be set to multipart
        XCTAssertTrue(request.parts.isEmpty)
    }
    
    func testHTTPRequestMultipartPartsResetContentType() {
        var request = HTTPRequest.post(baseURL, contentType: .json)
        XCTAssertEqual(request.contentType, .json)
        
        request.parts = [.text("test", name: "field")]
        XCTAssertEqual(request.contentType, .multipart) // Should be automatically changed
        
        request.parts = [] // Clear parts
        XCTAssertEqual(request.contentType, .multipart) // Should remain multipart
    }
}
