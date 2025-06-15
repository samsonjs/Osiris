//
//  FormEncoderTests.swift
//  OsirisTests
//
//  Created by Sami Samhuri on 2025-06-15.
//

@testable import Osiris
import XCTest

class FormEncoderTests: XCTestCase {
    func testEncodeEmptyDictionary() {
        let result = FormEncoder.encode([:])
        XCTAssertEqual(result, "")
    }
    
    func testEncodeSingleStringValue() {
        let parameters = ["name": "Jane Doe"]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "name=Jane%20Doe")
    }
    
    func testEncodeMultipleStringValues() {
        let parameters = ["name": "John", "email": "john@example.net"]
        let result = FormEncoder.encode(parameters)
        // Keys should be sorted alphabetically
        XCTAssertEqual(result, "email=john%40example.net&name=John")
    }
    
    func testEncodeIntegerValue() {
        let parameters = ["age": 30]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "age=30")
    }
    
    func testEncodeBooleanValues() {
        let parameters = ["active": true, "verified": false]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "active=1&verified=0")
    }
    
    func testEncodeNSNumberBooleanValues() {
        let parameters = ["active": NSNumber(value: true), "verified": NSNumber(value: false)]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "active=1&verified=0")
    }
    
    func testEncodeNSNumberIntegerValues() {
        let parameters = ["count": NSNumber(value: 42)]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "count=42")
    }
    
    func testEncodeNestedDictionary() {
        let personData: [String: any Sendable] = ["name": "Jane", "age": 30]
        let parameters: [String: any Sendable] = ["person": personData]
        let result = FormEncoder.encode(parameters)
        // Order can vary, so check both possible orderings
        let expected1 = "person%5Bage%5D=30&person%5Bname%5D=Jane"
        let expected2 = "person%5Bname%5D=Jane&person%5Bage%5D=30"
        XCTAssertTrue(result == expected1 || result == expected2, "Result '\(result)' doesn't match either expected format")
    }
    
    func testEncodeArray() {
        let parameters = ["tags": ["swift", "ios", "mobile"]]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "tags%5B%5D=swift&tags%5B%5D=ios&tags%5B%5D=mobile")
    }
    
    func testEncodeComplexNestedStructure() {
        let preferences: [String: any Sendable] = ["theme": "dark", "notifications": true]
        let tags: [any Sendable] = ["rockstar", "swiftie"]
        let personData: [String: any Sendable] = [
            "name": "Jane",
            "preferences": preferences,
            "tags": tags
        ]
        let parameters: [String: any Sendable] = ["person": personData]
        
        let result = FormEncoder.encode(parameters)
        // The actual order depends on how the dictionary is sorted, so let's test the components
        XCTAssertTrue(result.contains("person%5Bname%5D=Jane"))
        XCTAssertTrue(result.contains("person%5Bpreferences%5D%5Bnotifications%5D=1"))
        XCTAssertTrue(result.contains("person%5Bpreferences%5D%5Btheme%5D=dark"))
        XCTAssertTrue(result.contains("person%5Btags%5D%5B%5D=rockstar"))
        XCTAssertTrue(result.contains("person%5Btags%5D%5B%5D=swiftie"))
    }
    
    func testEncodeSpecialCharacters() {
        let parameters = ["message": "Hello & welcome to Abbey Road Studios! 100% music magic guaranteed."]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "message=Hello%20%26%20welcome%20to%20Abbey%20Road%20Studios%21%20100%25%20music%20magic%20guaranteed.")
    }
    
    func testEncodeUnicodeCharacters() {
        let parameters = ["emoji": "🚀👨‍💻", "chinese": "你好"]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "chinese=%E4%BD%A0%E5%A5%BD&emoji=%F0%9F%9A%80%F0%9F%91%A8%E2%80%8D%F0%9F%92%BB")
    }
    
    func testKeysAreSortedAlphabetically() {
        let parameters = ["zebra": "z", "alpha": "a", "beta": "b"]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "alpha=a&beta=b&zebra=z")
    }
    
    func testEncodeDoubleValue() {
        let parameters = ["price": 19.99]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "price=19.99")
    }
    
    func testEncodeNilValuesAsStrings() {
        // Swift's Any type handling - nil values become "<null>" strings
        let parameters = ["optional": NSNull()]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "optional=%3Cnull%3E")
    }
    
    func testRFC3986Compliance() {
        // Test that reserved characters are properly encoded according to RFC 3986
        let parameters = ["reserved": "!*'();:@&=+$,/?#[]"]
        let result = FormEncoder.encode(parameters)
        // According to the implementation, ? and / are NOT encoded per RFC 3986 Section 3.4
        XCTAssertEqual(result, "reserved=%21%2A%27%28%29%3B%3A%40%26%3D%2B%24%2C/?%23%5B%5D")
    }
    
    func testURLQueryAllowedCharacters() {
        // Test characters that should NOT be encoded
        let parameters = ["allowed": "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"]
        let result = FormEncoder.encode(parameters)
        XCTAssertEqual(result, "allowed=ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    }
    
    func testMixedDataTypes() {
        let array: [any Sendable] = [1, 2, 3]
        let nested: [String: any Sendable] = ["key": "nested_value"]
        let parameters: [String: any Sendable] = [
            "string": "value",
            "integer": 42,
            "boolean": true,
            "double": 3.14,
            "array": array,
            "nested": nested
        ]
        
        let result = FormEncoder.encode(parameters)
        let expected = "array%5B%5D=1&array%5B%5D=2&array%5B%5D=3&boolean=1&double=3.14&integer=42&nested%5Bkey%5D=nested_value&string=value"
        XCTAssertEqual(result, expected)
    }
}

// Test the NSNumber extension
class NSNumberBoolExtensionTests: XCTestCase {
    
    func testNSNumberIsBoolForBooleans() {
        let trueNumber = NSNumber(value: true)
        let falseNumber = NSNumber(value: false)
        
        XCTAssertTrue(trueNumber.isBool)
        XCTAssertTrue(falseNumber.isBool)
    }
    
    func testNSNumberIsBoolForIntegers() {
        let intNumber = NSNumber(value: 42)
        let zeroNumber = NSNumber(value: 0)
        let oneNumber = NSNumber(value: 1)
        
        XCTAssertFalse(intNumber.isBool)
        XCTAssertFalse(zeroNumber.isBool)
        XCTAssertFalse(oneNumber.isBool)
    }
    
    func testNSNumberIsBoolForDoubles() {
        let doubleNumber = NSNumber(value: 3.14)
        let zeroDouble = NSNumber(value: 0.0)
        
        XCTAssertFalse(doubleNumber.isBool)
        XCTAssertFalse(zeroDouble.isBool)
    }
}
