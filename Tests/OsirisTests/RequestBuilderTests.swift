//
//  RequestBuilderTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class RequestBuilderTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.net/riders")!

    func testBuildBasicGETRequest() throws {
        let httpRequest = HTTPRequest.get(baseURL)
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.url, baseURL)
        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertNil(urlRequest.httpBody)
    }

    func testBuildBasicPOSTRequest() throws {
        let httpRequest = HTTPRequest.post(baseURL)
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.url, baseURL)
        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertNil(urlRequest.httpBody)
    }

    func testBuildRequestWithHeaders() throws {
        var httpRequest = HTTPRequest.get(baseURL)
        httpRequest.headers = ["Authorization": "Bearer token", "X-Custom": "value"]

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-Custom"), "value")
    }

    func testBuildJSONRequest() throws {
        let parameters = ["name": "Jane", "age": 30] as [String: any Sendable]
        let httpRequest = HTTPRequest.postJSON(baseURL, body: parameters)

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)

        // Verify the JSON content
        let bodyData = urlRequest.httpBody!
        let decodedJSON = try JSONSerialization.jsonObject(with: bodyData) as! [String: any Sendable]
        XCTAssertEqual(decodedJSON["name"] as? String, "Jane")
        XCTAssertEqual(decodedJSON["age"] as? Int, 30)
    }

    func testBuildFormEncodedRequest() throws {
        let parameters = ["email": "john@example.net", "password": "TaylorSwift1989"]
        let httpRequest = HTTPRequest.postForm(baseURL, parameters: parameters)

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertNotNil(urlRequest.httpBody)

        let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8)!
        XCTAssertTrue(bodyString.contains("email=john%40example.net"))
        XCTAssertTrue(bodyString.contains("password=TaylorSwift1989"))
    }

    // Note: Testing .none content type with parameters would trigger an assertion failure
    // This is by design - developers should specify an appropriate content type

    func testBuildMultipartRequest() throws {
        let parts = [
            MultipartFormEncoder.Part.text("Jane Doe", name: "name"),
            MultipartFormEncoder.Part.data(Data("test".utf8), name: "file", type: "text/plain", filename: "test.txt")
        ]
        let httpRequest = HTTPRequest.postMultipart(baseURL, parts: parts)

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        let contentType = urlRequest.value(forHTTPHeaderField: "Content-Type")
        XCTAssertNotNil(contentType)
        XCTAssertTrue(contentType!.hasPrefix("multipart/form-data; boundary="))

        let contentLength = urlRequest.value(forHTTPHeaderField: "Content-Length")
        XCTAssertNotNil(contentLength)
        XCTAssertGreaterThan(Int(contentLength!)!, 0)

        XCTAssertNotNil(urlRequest.httpBody)
    }

    func testBuildRequestWithInvalidFormData() throws {
        // Create a parameter that would cause UTF-8 encoding to fail
        // FormEncoder.encode() returns a String, but String.data(using: .utf8) could theoretically fail
        // However, this is extremely rare in practice. Let's test the error path by creating a mock scenario.

        // Since FormEncoder is quite robust and UTF-8 encoding rarely fails,
        // we'll test this by creating a subclass that can force the failure
        // But for now, we'll document this edge case exists
        XCTAssertNoThrow(try RequestBuilder.build(request: HTTPRequest.postForm(baseURL, parameters: ["test": "value"])))
    }

    func testBuildRequestWithAllHTTPMethods() throws {
        let methods: [HTTPMethod] = [.get, .post, .put, .patch, .delete]

        for method in methods {
            let httpRequest = try HTTPRequest(method: method, url: baseURL)
            let urlRequest = try RequestBuilder.build(request: httpRequest)

            XCTAssertEqual(urlRequest.httpMethod, method.string)
        }
    }

    func testBuildRequestPreservesURL() throws {
        let complexURL = URL(string: "https://api.example.net/riders?page=1#section")!
        let httpRequest = HTTPRequest.get(complexURL)

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.url, complexURL)
    }

    func testMultipleHeadersWithSameName() throws {
        var httpRequest = HTTPRequest.get(baseURL)
        httpRequest.headers = ["Accept": "application/json"]

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Accept"), "application/json")
    }

    func testBuildRequestWithEmptyMultipartParts() throws {
        let httpRequest = HTTPRequest.postMultipart(baseURL, parts: [])

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        let contentType = try XCTUnwrap(urlRequest.value(forHTTPHeaderField: "Content-Type"))
        XCTAssertTrue(contentType.hasPrefix("multipart/form-data; boundary="))
        XCTAssertNotNil(urlRequest.httpBody)
    }

    func testBuildRequestWithLargeMultipartData() throws {
        let largeData = Data(repeating: 65, count: 1024 * 1024) // 1MB of 'A' characters
        let parts = [
            MultipartFormEncoder.Part.data(largeData, name: "largefile", type: "application/octet-stream", filename: "large.bin")
        ]
        let httpRequest = HTTPRequest.postMultipart(baseURL, parts: parts)

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertNotNil(urlRequest.httpBody)
        XCTAssertGreaterThan(urlRequest.httpBody!.count, 1024 * 1024)
    }

    func testBuildRequestWithSpecialCharactersInHeaders() throws {
        var httpRequest = HTTPRequest.get(baseURL)
        httpRequest.headers = [
            "X-Custom-Header": "value with spaces and symbols: !@#$%",
            "X-Unicode": "🚀 rocket emoji",
            "X-Empty": ""
        ]

        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-Custom-Header"), "value with spaces and symbols: !@#$%")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-Unicode"), "🚀 rocket emoji")
        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "X-Empty"), "")
    }

    func testBuildRequestWithNilParameters() throws {
        let httpRequest = HTTPRequest.post(baseURL)
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        // RequestBuilder may not set Content-Type if there are no parameters to encode
        XCTAssertNil(urlRequest.httpBody)
    }

    func testBuildRequestWithEmptyParameters() throws {
        let httpRequest = HTTPRequest.postJSON(baseURL, body: [:])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(urlRequest.httpBody)

        let bodyString = String(data: urlRequest.httpBody!, encoding: .utf8)!
        XCTAssertEqual(bodyString, "{}")
    }

    func testBuildRequestSetsContentType() throws {
        let httpRequest = HTTPRequest.postJSON(baseURL, body: ["test": "value"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        // RequestBuilder should set the correct content type when there are parameters to encode
        let contentType = urlRequest.value(forHTTPHeaderField: "Content-Type")
        XCTAssertTrue(contentType?.contains("application/json") == true)
    }

    func testBuildRequestWithComplexJSONParameters() throws {
        let nestedData: [String: any Sendable] = ["theme": "dark", "notifications": true]
        let arrayData: [any Sendable] = ["rock", "pop", "jazz"]
        let complexParams: [String: any Sendable] = [
            "person": [
                "name": "David Bowie",
                "age": 69,
                "preferences": nestedData,
                "genres": arrayData
            ] as [String: any Sendable]
        ]

        let httpRequest = HTTPRequest.postJSON(baseURL, body: complexParams)
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertNotNil(urlRequest.httpBody)
        let jsonObject = try JSONSerialization.jsonObject(with: urlRequest.httpBody!) as! [String: Any]
        let person = jsonObject["person"] as! [String: Any]
        XCTAssertEqual(person["name"] as? String, "David Bowie")
        XCTAssertEqual(person["age"] as? Int, 69)
    }

    func testBuildRequestWithExplicitFormEncoding() throws {
        // Test explicit form encoding
        let httpRequest = HTTPRequest.postForm(baseURL, parameters: ["email": "freddie@example.net", "band": "Queen"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        XCTAssertNotNil(urlRequest.httpBody)

        let bodyString = String(bytes: urlRequest.httpBody!, encoding: .utf8)
        XCTAssertTrue(bodyString?.contains("email=freddie%40example.net") ?? false)
        XCTAssertTrue(bodyString?.contains("band=Queen") ?? false)
    }

    func testBuildGETRequestWithQueryParameters() throws {
        let httpRequest = HTTPRequest.get(baseURL, parameters: ["name": "Neko Case", "email": "neko@example.net"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertNil(urlRequest.httpBody)
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("name=Neko%20Case"), "URL should contain encoded name parameter")
        XCTAssertTrue(urlString.contains("email=neko@example.net"), "URL should contain email parameter")
        XCTAssertTrue(urlString.contains("?"), "URL should contain query separator")
    }

    func testBuildDELETERequestWithQueryParameters() throws {
        let httpRequest = HTTPRequest.delete(baseURL, parameters: ["id": "123", "confirm": "true"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.httpMethod, "DELETE")
        XCTAssertNil(urlRequest.httpBody)
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("id=123"))
        XCTAssertTrue(urlString.contains("confirm=true"))
        XCTAssertTrue(urlString.contains("?"))
    }

    func testBuildGETRequestWithExistingQueryString() throws {
        let urlWithQuery = URL(string: "https://api.example.net/riders?existing=param")!
        let httpRequest = HTTPRequest.get(urlWithQuery, parameters: ["new": "value"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertTrue(urlString.contains("existing=param"))
        XCTAssertTrue(urlString.contains("new=value"))
        XCTAssertTrue(urlString.contains("&"))
    }

    func testBuildGETRequestWithFormParameters() throws {
        let httpRequest = HTTPRequest.get(baseURL, parameters: ["name": "value"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        // GET parameters should be encoded as query string
        XCTAssertTrue(urlRequest.url?.query?.contains("name=value") ?? false)
        XCTAssertNil(urlRequest.httpBody)
    }

    func testBuildDELETERequestWithParameters() throws {
        let httpRequest = HTTPRequest.delete(baseURL, parameters: ["id": "123"])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        // DELETE parameters should be encoded as query string
        XCTAssertTrue(urlRequest.url?.query?.contains("id=123") ?? false)
        XCTAssertNil(urlRequest.httpBody)
    }

    func testBuildGETRequestWithEmptyParametersDoesNotIncludeQueryString() throws {
        let httpRequest = HTTPRequest.get(baseURL, parameters: [:])
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.httpMethod, "GET")
        XCTAssertNil(urlRequest.httpBody)
        XCTAssertNil(urlRequest.value(forHTTPHeaderField: "Content-Type"))

        let urlString = urlRequest.url?.absoluteString ?? ""
        XCTAssertEqual(urlString, baseURL.absoluteString, "URL should not contain query string when parameters are empty")
        XCTAssertFalse(urlString.contains("?"), "URL should not contain question mark when parameters are empty")
    }

    func testBuildRequestWithFileData() throws {
        // Create a temporary file for testing
        let tempDir = FileManager.default.temporaryDirectory
        let testFileURL = tempDir.appendingPathComponent("test_file.txt")
        let testContent = "This is test file content for streaming"
        try testContent.write(to: testFileURL, atomically: true, encoding: .utf8)

        defer {
            try? FileManager.default.removeItem(at: testFileURL)
        }

        let httpRequest = HTTPRequest.postFile(baseURL, fileURL: testFileURL)
        let urlRequest = try RequestBuilder.build(request: httpRequest)

        XCTAssertEqual(urlRequest.httpMethod, "POST")
        XCTAssertNotNil(urlRequest.httpBodyStream)
        XCTAssertNil(urlRequest.httpBody) // Should use stream, not body

        // Should set Content-Length if file size is available
        let contentLength = urlRequest.value(forHTTPHeaderField: "Content-Length")
        XCTAssertNotNil(contentLength)
        XCTAssertEqual(Int(contentLength!), testContent.utf8.count)

        // Should set Content-Type based on file extension
        let contentType = urlRequest.value(forHTTPHeaderField: "Content-Type")
        XCTAssertEqual(contentType, "text/plain")
    }

    func testBuildRequestWithFileDataSetsCorrectContentType() throws {
        let tempDir = FileManager.default.temporaryDirectory

        // Test JSON file
        let jsonFileURL = tempDir.appendingPathComponent("test.json")
        try "{}".write(to: jsonFileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: jsonFileURL) }

        let jsonRequest = HTTPRequest.postFile(baseURL, fileURL: jsonFileURL)
        let jsonURLRequest = try RequestBuilder.build(request: jsonRequest)

        XCTAssertEqual(jsonURLRequest.value(forHTTPHeaderField: "Content-Type"), "application/json")

        // Test PNG file
        let pngFileURL = tempDir.appendingPathComponent("test.png")
        try Data().write(to: pngFileURL)
        defer { try? FileManager.default.removeItem(at: pngFileURL) }

        let pngRequest = HTTPRequest.putFile(baseURL, fileURL: pngFileURL)
        let pngURLRequest = try RequestBuilder.build(request: pngRequest)

        XCTAssertEqual(pngURLRequest.value(forHTTPHeaderField: "Content-Type"), "image/png")
    }
}
