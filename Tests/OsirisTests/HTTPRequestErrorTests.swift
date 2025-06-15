//
//  HTTPRequestErrorTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class HTTPRequestErrorTests: XCTestCase {

    func testHTTPError() {
        let error = HTTPRequestError.http
        XCTAssertEqual(error.localizedDescription, "HTTP request failed with non-2xx status code")
        XCTAssertEqual(error.failureReason, "The server returned an error status code")
        XCTAssertEqual(error.recoverySuggestion, "Check the server response for error details")
    }

    func testUnknownError() {
        let error = HTTPRequestError.unknown
        XCTAssertEqual(error.localizedDescription, "An unknown error occurred")
        XCTAssertEqual(error.failureReason, "An unexpected error occurred during the request")
        XCTAssertEqual(error.recoverySuggestion, "Check network connectivity and try again")
    }

    func testErrorDescriptionIsNeverNil() {
        let allErrors: [HTTPRequestError] = [
            .http,
            .unknown
        ]

        for error in allErrors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    func testFailureReasonIsNeverNil() {
        let allErrors: [HTTPRequestError] = [
            .http,
            .unknown
        ]

        for error in allErrors {
            XCTAssertNotNil(error.failureReason)
            XCTAssertFalse(error.failureReason!.isEmpty)
        }
    }

    func testRecoverySuggestionIsNeverNil() {
        let allErrors: [HTTPRequestError] = [
            .http,
            .unknown
        ]

        for error in allErrors {
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
}