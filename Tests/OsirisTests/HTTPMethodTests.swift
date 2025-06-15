//
//  HTTPMethodTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class HTTPMethodTests: XCTestCase {
    func testHTTPMethodStrings() {
        XCTAssertEqual(HTTPMethod.get.string, "GET")
        XCTAssertEqual(HTTPMethod.post.string, "POST")
        XCTAssertEqual(HTTPMethod.put.string, "PUT")
        XCTAssertEqual(HTTPMethod.patch.string, "PATCH")
        XCTAssertEqual(HTTPMethod.delete.string, "DELETE")
    }
}
