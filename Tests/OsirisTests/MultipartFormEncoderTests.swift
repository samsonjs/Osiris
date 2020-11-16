//
//  MultipartFormEncoderTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2020-10-20.
//  Copyright © 2020 Guru Logic Inc. All rights reserved.
//

@testable import Osiris
import XCTest

func AssertStringDataEqual(_ expression1: @autoclosure () throws -> Data, _ expression2: @autoclosure () throws -> String, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) {
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
        let body = try subject.encodeData(parts: [])
        XCTAssertEqual(body.contentType, "multipart/form-data; boundary=\"SuperAwesomeBoundary\"")
        AssertStringDataEqual(body.data, "--SuperAwesomeBoundary--")
    }

    func testEncodeText() throws {
        AssertStringDataEqual(
            try subject.encodeData(parts: [.text("Tina", name: "name")]).data,
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
        let data = Data("phony video data".utf8)
        AssertStringDataEqual(
            try subject.encodeData(parts: [
                .data(data, name: "video", type: "video/mp4", filename: "LiesSex&VideoTape.mp4"),
            ]).data,
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
        let imageData = Data("phony image data".utf8)
        let videoData = Data("phony video data".utf8)
        AssertStringDataEqual(
            try subject.encodeData(parts: [
                .text("Queso", name: "name"),
                .data(imageData, name: "image", type: "image/jpeg", filename: "feltcute.jpg"),
                .text("top of the bbq", name: "spot"),
                .data(videoData, name: "video", type: "video/mp4", filename: "LiesSex&VideoTape.mp4"),
            ]).data,
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
}
