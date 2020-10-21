//
//  MultipartFormEncoderTests.swift
//  VidjoTests
//
//  Created by Sami Samhuri on 2020-10-20.
//  Copyright © 2020 Guru Logic Inc. All rights reserved.
//

@testable import Osiris
import XCTest

func AssertBodyEqual(_ expression1: @autoclosure () throws -> Data, _ expression2: @autoclosure () throws -> String, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) {
    let data1 = try! expression1()
    let string1 = String(bytes: data1, encoding: .utf8)!
    let string2 = try! expression2()
    let message = message() ?? "\"\(string1)\" is not equal to \"\(string2)\""
    XCTAssertEqual(data1, Data(string2.utf8), message, file: file, line: line)
}

class MultipartFormEncoderTests: XCTestCase {
    var boundary = "SuperAwesomeBoundary"
    var subject: MultipartFormEncoder!

    override func setUpWithError() throws {
        subject = MultipartFormEncoder(boundary: boundary)
    }

    override func tearDownWithError() throws {
        subject = nil
    }

    func testEncodeNothing() throws {
        let body = subject.encode()
        XCTAssertEqual(body.contentType, "multipart/form-data; boundary=\"SuperAwesomeBoundary\"")
        AssertBodyEqual(body.data, "--SuperAwesomeBoundary--")
    }

    func testEncodeText() throws {
        subject.addPart(.text(name: "name", value: "Tina"))
        AssertBodyEqual(
            subject.encode().data,
            [
                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"name\"",
                "",
                "Tina",
                "--SuperAwesomeBoundary--",
            ].joined(separator: "\r\n")
        )
    }

    func testEncodeData() throws {
        subject.addPart(.binary(name: "video", data: Data("phony video data".utf8), type: "video/mp4", filename: "LiesSex&VideoTape.mp4"))
        AssertBodyEqual(
            subject.encode().data,
            [
                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"video\"; filename=\"LiesSex&VideoTape.mp4\"",
                "Content-Type: video/mp4",
                "Content-Length: 16",
                "",
                "phony video data",
                "--SuperAwesomeBoundary--"
            ].joined(separator: "\r\n")
        )
    }

    func testEncodeEverything() throws {
        subject.addPart(.text(name: "name", value: "Queso"))
        subject.addPart(.binary(name: "image", data: Data("phony image data".utf8), type: "image/jpeg", filename: "feltcute.jpg"))
        subject.addPart(.text(name: "spot", value: "top of the bbq"))
        subject.addPart(.binary(name: "video", data: Data("phony video data".utf8), type: "video/mp4", filename: "LiesSex&VideoTape.mp4"))
        AssertBodyEqual(
            subject.encode().data,
            [
                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"name\"",
                "",
                "Queso",

                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"image\"; filename=\"feltcute.jpg\"",
                "Content-Type: image/jpeg",
                "Content-Length: 16",
                "",
                "phony image data",

                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"spot\"",
                "",
                "top of the bbq",

                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"video\"; filename=\"LiesSex&VideoTape.mp4\"",
                "Content-Type: video/mp4",
                "Content-Length: 16",
                "",
                "phony video data",

                "--SuperAwesomeBoundary--"
            ].joined(separator: "\r\n")
        )
    }

    static var allTests = [
        ("testEncodeNothing", testEncodeNothing),
        ("testEncodeText", testEncodeText),
        ("testEncodeData", testEncodeData),
        ("testEncodeEverything", testEncodeEverything),
    ]
}
