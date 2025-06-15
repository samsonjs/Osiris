# Osiris

[![0 dependencies!](https://0dependencies.dev/0dependencies.svg)](https://0dependencies.dev)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FOsiris%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/samsonjs/Osiris)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FOsiris%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/samsonjs/Osiris)

## Overview

Osiris is a Swift library that provides a multipart form encoder and HTTP utilities designed to make working with HTTP requests simpler and more flexible. The library focuses on practical utility over complexity, offering tools that handle common HTTP tasks like multipart form encoding, request building, and response handling.

The main components include a robust `MultipartFormEncoder` that can encode forms either to memory or directly to files for streaming, and clean abstractions for HTTP requests and responses. All types conform to `CustomStringConvertible` with idiomatic descriptions, making debugging with OSLog significantly easier.

## Installation

You can install Osiris using Swift Package Manager (SPM) or copy the files directly into your project and customize them as needed.

### Supported Platforms

This package supports iOS 14.0+ and macOS 11.0+. The package is built with Swift 6.0+ but doesn't require projects importing Osiris to use Swift 6 language mode.

### Xcode

Add the package to your project's Package Dependencies by entering the URL `https://github.com/samsonjs/Osiris` and following the usual flow for adding packages.

### Swift Package Manager (SPM)

Add this to your Package.swift dependencies:

```swift
.package(url: "https://github.com/samsonjs/Osiris.git", .upToNextMajor(from: "2.0.0"))
```

and add `"Osiris"` to your target dependencies.

### Direct Integration

Alternatively, copy the files you want to use into your project and customize them to suit your needs.

## Usage

### Multipart Form Encoding

Create an encoder and then add parts to it as needed:

```swift
import Osiris

let avatarData = UIImage(systemName: "person.circle")?.jpegData(compressionQuality: 1.0)
let encoder = MultipartFormEncoder()
let body = try encoder.encodeData(parts: [
    .text("ziggy@example.net", name: "email"),
    .text("StarmanWaiting", name: "password"),
    .data(avatarData ?? Data(), name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
])
```

The form can be encoded as `Data` in memory, or to a file. There's a hard limit of 50 MB on encoding to memory but in practice you probably never want to go that high purely in memory. If you're adding any kind of image or video file then it's probably better to stream to a file.

```swift
let body = try encoder.encodeFile(parts: [
    .text("ziggy@example.net", name: "email"),
    .text("StarmanWaiting", name: "password"),
    .data(avatarData ?? Data(), name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
])

var request = URLRequest(url: URL(string: "https://example.net/accounts")!)
request.httpMethod = "POST"
request.httpBodyStream = InputStream(url: body.url)
request.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
request.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
```

### HTTPRequest

Basic usage:

```swift
let url = URL(string: "https://example.net")!

// GET request with query parameters
let getRequest = HTTPRequest.get(url, parameters: ["page": "1", "limit": "10"])

// DELETE request with query parameters  
let deleteRequest = HTTPRequest.delete(url, parameters: ["confirm": "true"])

// Or use the general initializer
let request = HTTPRequest(method: .get, url: url)
```

More advanced usage with parameters and headers:

```swift
let url = URL(string: "https://example.net")!
let params = ["email": "freddie@example.net", "password": "BohemianRhapsody"]

// POST with JSON parameters (goes in request body)
let request = HTTPRequest.post(url, contentType: .json, parameters: params)
request.addHeader(name: "x-custom", value: "42")
request.addMultipartJPEG(name: "avatar", image: UIImage(), quality: 1, filename: "avatar.jpg")
```

### Codable Support

For modern Swift applications, Osiris provides first-class support for `Codable` types with JSON encoding and decoding:

```swift
// Define your models
struct Person: Codable, Sendable {
    let name: String
    let email: String
    let age: Int
}

// POST request with Codable body
let person = Person(name: "Jane Doe", email: "jane@example.net", age: 30)
let request = HTTPRequest.postJSON(url, body: person)

// Build and send the request
let urlRequest = try RequestBuilder.build(request: request)
let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
    let httpResponse = HTTPResponse(response: response, data: data, error: error)
    
    switch httpResponse {
    case .success(_, _):
        // Decode the response
        let updatedPerson = try httpResponse.decode(Person.self)
        print("Updated person: \(updatedPerson)")
        
        // Or use the optional variant
        if let person = httpResponse.tryDecode(Person.self) {
            print("Decoded person: \(person)")
        }
    case .failure(let error, _, _):
        print("Request failed: \(error)")
    }
}
```

The Codable body takes precedence over the parameters dictionary, so you can safely use both without conflicts.

You can build a `URLRequest` from an `HTTPRequest` instance using `RequestBuilder`:

```swift
let urlRequest = try RequestBuilder.build(request: request)
```

### HTTPResponse

This enum makes sense of the 3 parameters of `URLSession`'s completion block. Its initializer takes in the optional `URLResponse`, `Data`, and `Error` values and determines if the request succeeded or failed, taking the HTTP status code into account. 200-level statuses are successes and anything else is a failure.

```swift
let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
    let httpResponse = HTTPResponse(response: response, data: data, error: error)
    
    switch httpResponse {
    case .success(let httpURLResponse, let data):
        print("Success: \(httpURLResponse.statusCode)")
        if let data = data {
            print("Response: \(String(data: data, encoding: .utf8) ?? "")")
        }
    case .failure(let error, let httpURLResponse, let data):
        print("Failed: \(error)")
        if let httpURLResponse = httpURLResponse {
            print("Status: \(httpURLResponse.statusCode)")
        }
    }
}
```

The response provides convenient properties:

- `data`: the optional body data returned by the server
- `status`: the HTTP status code returned by the server, or 0 if the request itself failed
- `headers`: a dictionary of headers
- `bodyString`: the response body as a `String`
- `dictionaryFromJSON`: the decoded body for JSON responses
- `decode(_:using:)`: decode the response body as a Codable type (throws on failure)
- `tryDecode(_:using:)`: decode the response body as a Codable type (returns nil on failure)
- `underlyingResponse`: the optional `HTTPURLResponse` for direct access

### FormEncoder

URL-encoded form data encoder adapted from [Alamofire][]:

```swift
let body = FormEncoder.encode(["email": "bowie@example.net", "password": "MajorTom"])
// => "email=bowie%40example.net&password=MajorTom"
```

[Alamofire]: https://github.com/Alamofire/Alamofire

### Complete Example

Here's how everything comes together:

```swift
import Osiris

// Create an HTTP request
let url = URL(string: "https://httpbin.org/post")!
let request = HTTPRequest(method: .post, url: url)

// Add multipart form data
let encoder = MultipartFormEncoder()
let formData = try encoder.encodeData(parts: [
    .text("John Doe", name: "name"),
    .text("john@example.net", name: "email"),
])

// Build URLRequest
var urlRequest = try RequestBuilder.build(request: request)
urlRequest.httpBody = formData.data
urlRequest.addValue(formData.contentType, forHTTPHeaderField: "Content-Type")

// Make the request
let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
    let httpResponse = HTTPResponse(response: response, data: data, error: error)
    
    switch httpResponse {
    case .success(let httpURLResponse, let data):
        print("Upload successful: \(httpURLResponse.statusCode)")
    case .failure(let error, _, _):
        print("Upload failed: \(error)")
    }
}
task.resume()
```

## Credits

Originally created by [@samsonjs][] for [1 Second Everyday][1SE]. `FormEncoder.swift` was adapted from [Alamofire][].

[1SE]: https://1se.co
[Alamofire]: https://github.com/Alamofire/Alamofire
[@samsonjs]: https://github.com/samsonjs

## License

Copyright © 2017-2025 [1 Second Everyday][1SE]. Released under the terms of the [MIT License][MIT].

[MIT]: https://sjs.mit-license.org
