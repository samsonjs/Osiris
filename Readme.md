# Osiris

[![0 dependencies!](https://0dependencies.dev/0dependencies.svg)](https://0dependencies.dev)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FOsiris%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/samsonjs/Osiris)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fsamsonjs%2FOsiris%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/samsonjs/Osiris)

## Overview

Osiris is a Swift library that makes HTTP requests less painful. It gives you multipart form encoding, cleaner abstractions for requests and responses, and stops you from wrangling optionals and errors manually. Instead you get proper enums and types that feel more Swifty.

The main components are clean abstractions for HTTP requests and responses, and a `MultipartFormEncoder` that can encode forms either to memory or to files. The multipart encoder can stream data to files for large request bodies. Everything conforms to `CustomStringConvertible` with helpful descriptions so debugging with OSLog doesn't involve `String(describing:)` or other annoyances.

## Installation

You can install Osiris using Swift Package Manager (SPM) or copy the files directly into your project and customize them as needed.

### Supported Platforms

This package supports iOS 16.0+ and macOS 13.0+. The package is built with Swift 6.0+ but doesn't require projects importing Osiris to use Swift 6 language mode.

### Xcode

Add the package to your project's Package Dependencies by entering the URL `https://github.com/samsonjs/Osiris` and following the usual flow for adding packages.

### Swift Package Manager (SPM)

Add this to your Package.swift dependencies:

```swift
.package(url: "https://github.com/samsonjs/Osiris.git", .upToNextMajor(from: "2.1.0"))
```

and add `"Osiris"` to your target dependencies.

### Direct Integration

Alternatively, copy the files you want to use into your project and customize them to suit your needs.

## Usage

### HTTPRequest

Basic usage:

```swift
import Osiris

let url = URL(string: "https://example.net/kittens")!

// Basic GET request
let request = HTTPRequest.get(url)

// GET request with query parameters
let getRequest = HTTPRequest.get(url, parameters: ["page": "1", "limit": "10"])

// DELETE request with query parameters
let deleteRequest = HTTPRequest.delete(url, parameters: ["confirm": "true"])
```

More complicated POST requests with bodies and headers:

```swift
let url = URL(string: "https://example.net/puppies")!

let params = ["email": "fatmike@example.net", "password": "LinoleumSupportsMyHead"]

// POST with JSON body
let jsonRequest = HTTPRequest.postJSON(url, body: params)

// POST with form-encoded body
let formRequest = HTTPRequest.postForm(url, parameters: params)

// POST with multipart body
let multipartRequest = HTTPRequest.postMultipart(url, parts: [.text("all day", name: "album")])

// Add headers to any request
var request = jsonRequest
request.addHeader(name: "x-the-answer", value: "42")
```

You can build a `URLRequest` from an `HTTPRequest` using `RequestBuilder`:

```swift
let urlRequest = try RequestBuilder.build(request: request)
```

### Type-Safe Requests with CodableRequest

For even better type safety, use `CodableRequest` to get compile-time verification of your response types:

```swift
struct Rider: Codable {
    let id: Int
    let name: String
    let email: String
    let bike: String
}

// Type-safe GET request
let getRiderRequest: CodableRequest<Rider> = .get(
    URL(string: "https://trails.example.net/rider/danny-macaskill")!
)

// Type-safe POST with Codable body
let newRider = Rider(id: 0, name: "Rachel Atherton", email: "rachel@example.net", bike: "Trek Session")
let createRiderRequest: CodableRequest<Rider> = try .post(
    URL(string: "https://trails.example.net/riders")!,
    body: newRider
)
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
- `underlyingResponse`: the optional `HTTPURLResponse` for direct access

### FormEncoder

URL-encoded form data encoder adapted from [Alamofire][]:

```swift
let body = FormEncoder.encode(["email": "trent@example.net", "password": "CloserToGod"])
// => "email=trent%40example.net&password=CloserToGod"
```

[Alamofire]: https://github.com/Alamofire/Alamofire

### Multipart Form Encoding

Create an encoder and then add parts to it as needed:

```swift
let avatarData = UIImage(systemName: "person.circle")?.jpegData(compressionQuality: 1.0)
let encoder = MultipartFormEncoder()
let body = try encoder.encodeData(parts: [
    .text("chali@example.net", name: "email"),
    .text("QualityControl", name: "password"),
    .data(avatarData ?? Data(), name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
])
```

You can encode forms as `Data` in memory, or encode to a file which can then be streamed from disk. There's a 50 MB limit on in-memory encoding, but honestly you probably don't want to go anywhere near that. If you're dealing with images or video files, just encode to a file from the start.

```swift
let body = try encoder.encodeFile(parts: [
    .text("chali@example.net", name: "email"),
    .text("QualityControl", name: "password"),
    .data(avatarData ?? Data(), name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
])

var request = URLRequest(url: URL(string: "https://example.net/accounts")!)
request.httpMethod = "POST"
request.httpBodyStream = InputStream(url: body.url)
request.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
request.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")

// Clean up the temporary file when done
defer { _ = body.cleanup() }
```

### Complete Example

Here's a realistic example with error handling:

```swift
import Osiris

struct ArtistProfile: Codable {
    let name: String
    let email: String
    let genre: String
}

func updateProfile(name: String, email: String, genre: String) async throws -> ArtistProfile {
    let url = URL(string: "https://beats.example.net/profile")!
    let request = HTTPRequest.putJSON(url, body: ["name": name, "email": email, "genre": genre])
    let urlRequest = try RequestBuilder.build(request: request)

    let (data, response) = try await URLSession.shared.data(for: urlRequest)
    let httpResponse = HTTPResponse(response: response, data: data, error: nil)

    switch httpResponse {
    case let .success(_, responseData):
        return try JSONDecoder().decode(ArtistProfile.self, from: responseData)
    case let .failure(error, httpResponse, _):
        if let httpResponse = httpResponse, httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        }
        throw error
    }
}

// Usage
do {
    let profile = try await updateProfile(name: "Trent Reznor", email: "trent@example.net", genre: "Industrial")
    print("Profile updated: \(profile)")
} catch {
    print("Failed to update profile: \(error)")
}
```

## Migration Guide

### Migrating from 2.0.x to 2.1.0

Version 2.1.0 cleans up the API while keeping everything backward compatible. The old methods are deprecated and you'll get warnings, but they still work. We'll remove them in 3.0.0.

#### HTTPRequest Changes

**Old API (deprecated):**
```swift
// Parameters with content type
let request = HTTPRequest.post(url, contentType: .json, parameters: ["key": "value"])
let request = HTTPRequest.put(url, contentType: .formEncoded, parameters: params)

// Direct property access
var request = HTTPRequest.post(url)
request.parameters = ["key": "value"]
request.parts = [.text("value", name: "field")]
```

**New API:**
```swift
// Explicit methods for different encodings
let request = HTTPRequest.postJSON(url, body: ["key": "value"])
let request = HTTPRequest.putForm(url, parameters: params)

// Multipart convenience methods
let request = HTTPRequest.postMultipart(url, parts: [.text("value", name: "field")])

// Codable support
struct Artist: Codable {
    let name: String
    let genre: String
}
let request = try HTTPRequest.post(url, body: Artist(name: "Trent Reznor", genre: "Industrial"))
```

#### What's Different

1. **GET/DELETE Query Parameters**: You can now pass parameters to GET and DELETE requests and they'll be automatically encoded as query strings like they should have been all along, instead of having to build the URL yourself.

2. **Type-Safe Requests**: There's a new `CodableRequest` type that gives you compile-time type safety:
   ```swift
   let request: CodableRequest<ArtistResponse> = .post(url, body: newArtist)
   ```

3. **Clearer Method Names**: Methods like `postJSON()` and `postForm()` tell you exactly what encoding you're getting, so no more guessing.

#### Migration Steps

1. Update to version 2.1.0
2. Fix the deprecation warnings by swapping old method calls for new ones
3. You can now pass query parameters to GET/DELETE requests instead of adding them to the URL yourself
4. Maybe try out `CodableRequest` for type-safe API calls while you're at it
5. When you're ready, update to 3.0.0 (that's when we'll remove the old methods)

## Credits

Originally created by [@samsonjs][] for [1 Second Everyday][1SE]. `FormEncoder.swift` was adapted from [Alamofire][].

[1SE]: https://1se.co
[Alamofire]: https://github.com/Alamofire/Alamofire
[@samsonjs]: https://github.com/samsonjs

## License

Copyright © 2017-2025 [1 Second Everyday][1SE]. Released under the terms of the [MIT License][MIT].

[MIT]: https://sjs.mit-license.org
