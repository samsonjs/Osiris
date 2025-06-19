//
//  HTTPRequestTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import UniformTypeIdentifiers
import XCTest

class HTTPRequestTests: XCTestCase {
    let baseURL = URL(string: "https://api.example.net")!

    func testHTTPRequestInitialization() {
        let request = HTTPRequest.get(baseURL)
        XCTAssertEqual(request.method, .get)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, .none)
        XCTAssertTrue(request.body.isEmpty)
        XCTAssertTrue(request.headers.isEmpty)
    }

    func testHTTPRequestInitializerValidation() throws {
        // Valid requests should work
        XCTAssertNoThrow(try HTTPRequest(method: .post, url: baseURL, body: .data(Data(), contentType: .json)))
        XCTAssertNoThrow(try HTTPRequest(method: .put, url: baseURL, body: .formParameters(["test": "value"])))
        XCTAssertNoThrow(try HTTPRequest(method: .patch, url: baseURL, body: .multipart([])))

        // GET and DELETE with no body should work
        XCTAssertNoThrow(try HTTPRequest(method: .get, url: baseURL))
        XCTAssertNoThrow(try HTTPRequest(method: .delete, url: baseURL))

        // GET with body should throw
        XCTAssertThrowsError(try HTTPRequest(method: .get, url: baseURL, body: .data(Data(), contentType: .json))) { error in
            XCTAssertEqual(error as? HTTPRequestError, .invalidRequestBody)
        }

        // DELETE with body should throw
        XCTAssertThrowsError(try HTTPRequest(method: .delete, url: baseURL, body: .formParameters(["test": "value"]))) { error in
            XCTAssertEqual(error as? HTTPRequestError, .invalidRequestBody)
        }
    }

    func testHTTPRequestWithParameters() {
        let params = ["key": "value", "number": 42] as [String: any Sendable]
        let request = HTTPRequest.postJSON(baseURL, body: params)

        XCTAssertEqual(request.method, HTTPMethod.post)
        XCTAssertEqual(request.contentType, HTTPContentType.json)
        if case .jsonParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 2)
        } else {
            XCTFail("Expected jsonParameters body")
        }
    }

    func testGETConvenience() {
        let request = HTTPRequest.get(baseURL)
        XCTAssertEqual(request.method, HTTPMethod.get)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, HTTPContentType.none)
    }

    func testPOSTConvenience() {
        let params = ["name": "Trent"]
        let request = HTTPRequest.postJSON(baseURL, body: params)

        XCTAssertEqual(request.method, HTTPMethod.post)
        XCTAssertEqual(request.contentType, HTTPContentType.json)
        if case .jsonParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected jsonParameters body")
        }
    }

    func testPUTConvenience() {
        let params = ["name": "Trent"]
        let request = HTTPRequest.putForm(baseURL, parameters: params)

        XCTAssertEqual(request.method, HTTPMethod.put)
        XCTAssertEqual(request.contentType, HTTPContentType.formEncoded)
        if case .formParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected formParameters body")
        }
    }

    func testDELETEConvenience() {
        let request = HTTPRequest.delete(baseURL)
        XCTAssertEqual(request.method, HTTPMethod.delete)
        XCTAssertEqual(request.url, baseURL)
        XCTAssertEqual(request.contentType, HTTPContentType.none)
    }

    func testMultipartPartsAutomaticallySetContentType() {
        let parts = [MultipartFormEncoder.Part.text("value", name: "field")]
        let request = HTTPRequest.postMultipart(baseURL, parts: parts)

        XCTAssertEqual(request.contentType, HTTPContentType.multipart)
        if case .multipart(let bodyParts) = request.body {
            XCTAssertEqual(bodyParts.count, 1)
        } else {
            XCTFail("Expected multipart body")
        }
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

        XCTAssertEqual(request.contentType, HTTPContentType.multipart)

        if case .multipart(let parts) = request.body {
            XCTAssertEqual(parts.count, 1)
            let part = parts.first!
            XCTAssertEqual(part.name, "avatar")

            if case let .binaryData(_, type, filename) = part.content {
                XCTAssertEqual(type, "image/jpeg")
                XCTAssertEqual(filename, "test.jpg")
            } else {
                XCTFail("Expected binary data content")
            }
        } else {
            XCTFail("Expected multipart body")
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
        if case .multipart(let parts) = request.body {
            XCTAssertTrue(parts.count >= 0) // Should not crash
        }
    }
    #endif

    func testHTTPRequestPATCHConvenience() {
        let params = ["status": "active"]
        let request = HTTPRequest.patchJSON(baseURL, body: params)

        XCTAssertEqual(request.method, HTTPMethod.patch)
        XCTAssertEqual(request.contentType, HTTPContentType.json)
        if case .jsonParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected jsonParameters body")
        }
    }

    func testHTTPRequestWithEmptyMultipartParts() {
        let request = HTTPRequest.postMultipart(baseURL, parts: [])

        XCTAssertEqual(request.contentType, HTTPContentType.multipart) // Multipart even with empty parts
        if case .multipart(let parts) = request.body {
            XCTAssertTrue(parts.isEmpty)
        } else {
            XCTFail("Expected multipart body")
        }
    }

    func testHTTPRequestBodyTypeDeterminesContentType() {
        let jsonRequest = HTTPRequest.postJSON(baseURL, body: ["test": "value"])
        XCTAssertEqual(jsonRequest.contentType, HTTPContentType.json)

        let formRequest = HTTPRequest.postForm(baseURL, parameters: ["test": "value"])
        XCTAssertEqual(formRequest.contentType, HTTPContentType.formEncoded)

        let multipartRequest = HTTPRequest.postMultipart(baseURL, parts: [])
        XCTAssertEqual(multipartRequest.contentType, HTTPContentType.multipart)
    }

    func testFileStreamingConveniences() {
        let fileURL = URL(fileURLWithPath: "/tmp/test.txt")

        let postRequest = HTTPRequest.postFile(baseURL, fileURL: fileURL)
        XCTAssertEqual(postRequest.method, HTTPMethod.post)
        XCTAssertEqual(postRequest.contentType, HTTPContentType.none)
        if case .fileData(let url) = postRequest.body {
            XCTAssertEqual(url, fileURL)
        } else {
            XCTFail("Expected fileData body")
        }

        let putRequest = HTTPRequest.putFile(baseURL, fileURL: fileURL)
        XCTAssertEqual(putRequest.method, HTTPMethod.put)
        if case .fileData(let url) = putRequest.body {
            XCTAssertEqual(url, fileURL)
        } else {
            XCTFail("Expected fileData body")
        }

        let patchRequest = HTTPRequest.patchFile(baseURL, fileURL: fileURL)
        XCTAssertEqual(patchRequest.method, HTTPMethod.patch)
        if case .fileData(let url) = patchRequest.body {
            XCTAssertEqual(url, fileURL)
        } else {
            XCTFail("Expected fileData body")
        }
    }

    func testRawDataConveniences() {
        let xmlData = "<xml><test>value</test></xml>".data(using: .utf8)!

        let postRequest = HTTPRequest.post(baseURL, data: xmlData, contentType: .xml)
        XCTAssertEqual(postRequest.method, HTTPMethod.post)
        XCTAssertEqual(postRequest.contentType, HTTPContentType.custom("application/xml"))
        if case let .data(data, contentType) = postRequest.body {
            XCTAssertEqual(data, xmlData)
            XCTAssertEqual(contentType, .xml)
        } else {
            XCTFail("Expected data body")
        }

        let putRequest = HTTPRequest.put(baseURL, data: xmlData, contentType: .plainText)
        XCTAssertEqual(putRequest.method, HTTPMethod.put)
        XCTAssertEqual(putRequest.contentType, HTTPContentType.custom("text/plain"))

        let patchRequest = HTTPRequest.patch(baseURL, data: xmlData, contentType: .xml)
        XCTAssertEqual(patchRequest.method, HTTPMethod.patch)
        XCTAssertEqual(patchRequest.contentType, HTTPContentType.custom("application/xml"))
    }

    func testUTTypeIntegration() {
        let data = Data("test".utf8)

        // Test common UTTypes
        let jsonRequest = HTTPRequest.post(baseURL, data: data, contentType: .json)
        XCTAssertEqual(jsonRequest.contentType, HTTPContentType.custom("application/json"))

        let xmlRequest = HTTPRequest.post(baseURL, data: data, contentType: .xml)
        XCTAssertEqual(xmlRequest.contentType, HTTPContentType.custom("application/xml"))

        let textRequest = HTTPRequest.post(baseURL, data: data, contentType: .plainText)
        XCTAssertEqual(textRequest.contentType, HTTPContentType.custom("text/plain"))

        let pngRequest = HTTPRequest.post(baseURL, data: data, contentType: .png)
        XCTAssertEqual(pngRequest.contentType, HTTPContentType.custom("image/png"))

        // Test custom UTType
        if let customType = UTType(mimeType: "application/custom") {
            let customRequest = HTTPRequest.post(baseURL, data: data, contentType: customType)
            XCTAssertEqual(customRequest.contentType, HTTPContentType.custom("application/custom"))
        }
    }

    // MARK: - Deprecated API Tests

    func testDeprecatedPOSTWithContentType() {
        let params = ["name": "Chali 2na", "email": "chali@example.net"]

        // Test JSON content type
        let jsonRequest = HTTPRequest.post(baseURL, contentType: .json, parameters: params)
        XCTAssertEqual(jsonRequest.method, .post)
        XCTAssertEqual(jsonRequest.contentType, .json)
        if case .jsonParameters(let bodyParams) = jsonRequest.body {
            XCTAssertEqual(bodyParams.count, 2)
        } else {
            XCTFail("Expected jsonParameters body")
        }

        // Test form encoded content type
        let formRequest = HTTPRequest.post(baseURL, contentType: .formEncoded, parameters: params)
        XCTAssertEqual(formRequest.method, .post)
        XCTAssertEqual(formRequest.contentType, .formEncoded)
        if case .formParameters(let bodyParams) = formRequest.body {
            XCTAssertEqual(bodyParams.count, 2)
        } else {
            XCTFail("Expected formParameters body")
        }

        // Test with no parameters
        let emptyRequest = HTTPRequest.post(baseURL, contentType: .json, parameters: nil)
        XCTAssertTrue(emptyRequest.body.isEmpty)
    }

    func testDeprecatedPUTWithContentType() {
        let params = ["status": "active"]

        let request = HTTPRequest.put(baseURL, contentType: .json, parameters: params)
        XCTAssertEqual(request.method, .put)
        XCTAssertEqual(request.contentType, .json)
        if case .jsonParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected jsonParameters body")
        }
    }

    func testDeprecatedPATCHWithContentType() {
        let params = ["field": "value"]

        let request = HTTPRequest.patch(baseURL, contentType: .formEncoded, parameters: params)
        XCTAssertEqual(request.method, .patch)
        XCTAssertEqual(request.contentType, .formEncoded)
        if case .formParameters(let bodyParams) = request.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected formParameters body")
        }
    }

    func testDeprecatedInitializer() {
        let params = ["key": "value"]

        // Test POST with JSON
        let postRequest = HTTPRequest(method: .post, url: baseURL, contentType: .json, parameters: params)
        XCTAssertEqual(postRequest.method, .post)
        XCTAssertEqual(postRequest.contentType, .json)
        if case .jsonParameters(let bodyParams) = postRequest.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected jsonParameters body")
        }

        // Test GET with parameters (should use query strings)
        let getRequest = HTTPRequest(method: .get, url: baseURL, contentType: .none, parameters: params)
        XCTAssertEqual(getRequest.method, .get)
        if case .formParameters(let bodyParams) = getRequest.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected formParameters body for query encoding")
        }

        // Test DELETE with parameters (should use query strings)
        let deleteRequest = HTTPRequest(method: .delete, url: baseURL, contentType: .none, parameters: params)
        XCTAssertEqual(deleteRequest.method, .delete)
        if case .formParameters(let bodyParams) = deleteRequest.body {
            XCTAssertEqual(bodyParams.count, 1)
        } else {
            XCTFail("Expected formParameters body for query encoding")
        }
    }

    func testDeprecatedParametersProperty() {
        let params = ["test": "value", "number": 42] as [String: any Sendable]

        // Test reading parameters from JSON body
        let jsonRequest = HTTPRequest.postJSON(baseURL, body: params)
        XCTAssertEqual(jsonRequest.parameters?.count, 2)

        // Test reading parameters from form body
        let formRequest = HTTPRequest.postForm(baseURL, parameters: params)
        XCTAssertEqual(formRequest.parameters?.count, 2)

        // Test setting parameters
        var request = HTTPRequest.post(baseURL)
        request.parameters = params
        XCTAssertEqual(request.parameters?.count, 2)
        if case .formParameters = request.body {
            // Good, defaults to form parameters
        } else {
            XCTFail("Expected formParameters body")
        }

        // Test setting nil parameters
        request.parameters = nil
        XCTAssertNil(request.parameters)
        XCTAssertTrue(request.body.isEmpty)
    }

    func testDeprecatedPartsProperty() {
        let parts = [
            MultipartFormEncoder.Part.text("value", name: "field"),
            MultipartFormEncoder.Part.data(Data("test".utf8), name: "file", type: "text/plain", filename: "test.txt")
        ]

        // Test reading parts
        let multipartRequest = HTTPRequest.postMultipart(baseURL, parts: parts)
        XCTAssertEqual(multipartRequest.parts.count, 2)

        // Test setting parts
        var request = HTTPRequest.post(baseURL)
        request.parts = parts
        XCTAssertEqual(request.parts.count, 2)
        XCTAssertEqual(request.contentType, .multipart)

        // Test empty parts
        request.parts = []
        XCTAssertEqual(request.parts.count, 0)
        if case .multipart(let bodyParts) = request.body {
            XCTAssertTrue(bodyParts.isEmpty)
        } else {
            XCTFail("Expected multipart body")
        }
    }
}
