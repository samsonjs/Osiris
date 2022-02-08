//
//  MultipartFormEncoderTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2020-10-20.
//  Copyright © 2020 Guru Logic Inc. All rights reserved.
//

@testable import Osiris
import XCTest

func AssertStringDataEqual(_ expression1: @autoclosure () throws -> Data, _ expression2: @autoclosure () throws -> String, _ message: @autoclosure () -> String? = nil, file: StaticString = #filePath, line: UInt = #line) throws {
    let data1 = try expression1()
    let string1 = String(bytes: data1, encoding: .utf8)!
    let string2 = try expression2()
    let message = message() ?? "\"\(string1)\" is not equal to \"\(string2)\""
    XCTAssertEqual(data1, Data(string2.utf8), message, file: file, line: line)
}

class MultipartFormEncoderTests: XCTestCase {
    var subject: MultipartFormEncoder!

    override func setUpWithError() throws {
        subject = MultipartFormEncoder(boundary: "SuperAwesomeBoundary")
    }

    override func tearDownWithError() throws {
        subject = nil
    }

    func testConstructTextPart() {
        let part = MultipartFormEncoder.Part.text("value", name: "name")
        XCTAssertEqual(part, MultipartFormEncoder.Part(name: "name", content: .text("value")))
    }

    func testConstructDataPart() {
        let data = Data("value".utf8)
        let part = MultipartFormEncoder.Part.data(data, name: "name", type: "text/plain", filename: "something.txt")
        let expected = MultipartFormEncoder.Part(name: "name", content: .binaryData(data, type: "text/plain", filename: "something.txt"))
        XCTAssertEqual(part, expected)
    }

    func testConstructBinaryFilePart() throws {
        let url = Bundle.module.url(forResource: "notbad", withExtension: "jpg")!
        let part = try MultipartFormEncoder.Part.file(url, name: "name", type: "image/jpeg")
        let expected = MultipartFormEncoder.Part(name: "name", content: .binaryFile(url, size: 22_680, type: "image/jpeg", filename: "notbad.jpg"))
        XCTAssertEqual(part, expected)
    }

    func testConstructInvalidFilePart() {
        let url = Bundle.module.url(forResource: "notbad", withExtension: "jpg")!
            .appendingPathComponent("busted")
        XCTAssertThrowsError(try MultipartFormEncoder.Part.file(url, name: "name", type: "image/jpeg"))
    }

    func testEncodeNothing() throws {
        let body = try subject.encodeData(parts: [])
        XCTAssertEqual(body.contentType, "multipart/form-data; boundary=\"SuperAwesomeBoundary\"")
        XCTAssertEqual(body.contentLength, 24)
        try AssertStringDataEqual(body.data, "--SuperAwesomeBoundary--")
    }

    func testEncodeText() throws {
        try AssertStringDataEqual(
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

    func testEncodeEmptyText() throws {
        try AssertStringDataEqual(
            try subject.encodeData(parts: [.text("", name: "name")]).data,
            [
                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"name\"",
                "",
                "",
                "--SuperAwesomeBoundary--",
            ].joined(separator: "\r\n")
        )
    }

    func testEncodeData() throws {
        let data = Data("phony video data".utf8)
        try AssertStringDataEqual(
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
                "--SuperAwesomeBoundary--",
            ].joined(separator: "\r\n")
        )
    }

    func testEncodeFile() throws {
        let url = Bundle.module.url(forResource: "lorem", withExtension: "txt")!
        let body = try subject.encodeFile(parts: [
            .file(url, name: "lorem", type: "text/plain"),
        ])
        XCTAssertEqual(body.contentType, "multipart/form-data; boundary=SuperAwesomeBoundary")
        XCTAssertEqual(body.contentLength, 3586)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: body.url.path)[.size] as! UInt64, 3586)
        XCTAssertEqual(try String(contentsOf: body.url), [
            "--SuperAwesomeBoundary",
            "Content-Disposition: form-data; name=\"lorem\"; filename=\"lorem.txt\"",
            "Content-Type: text/plain",
            "Content-Length: 3418",
            "",
            try! String(contentsOf: url),

            "--SuperAwesomeBoundary--",
        ].joined(separator: "\r\n"))
    }

    func testEncodeEverything() throws {
        let imageData = Data("phony image data".utf8)
        let videoData = Data("phony video data".utf8)
        let url = Bundle.module.url(forResource: "lorem", withExtension: "txt")!
        try AssertStringDataEqual(
            try subject.encodeData(parts: [
                .text("Queso", name: "name"),
                .data(imageData, name: "image", type: "image/jpeg", filename: "feltcute.jpg"),
                .text("top of the bbq", name: "spot"),
                .data(videoData, name: "video", type: "video/mp4", filename: "LiesSex&VideoTape.mp4"),
                .file(url, name: "lorem", type: "text/plain"),
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

                "--SuperAwesomeBoundary",
                "Content-Disposition: form-data; name=\"lorem\"; filename=\"lorem.txt\"",
                "Content-Type: text/plain",
                "Content-Length: 3418",
                "",
                try! String(contentsOf: url),

                "--SuperAwesomeBoundary--",
            ].joined(separator: "\r\n")
        )
    }
}
