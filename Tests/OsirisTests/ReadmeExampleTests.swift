//
// Created by Sami Samhuri on 2025-06-23.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation
@testable import Osiris

func httpRequestWithCodableSupport() async throws {
    let url = URL(string: "https://trails.example.net/riders")!

    // GET request with automatic JSON decoding
    let riders: [RiderProfile] = try await URLSession.shared.perform(.get(url))

    // POST with Codable body and automatic response decoding
    struct CreateRiderRequest: Codable {
        let name: String
        let email: String
        let bike: String
    }

    let danny = CreateRiderRequest(name: "Danny MacAskill", email: "danny@trails.example.net", bike: "Santa Cruz 5010")
    let created: RiderProfile = try await URLSession.shared.perform(.post(url, body: danny))

    // Custom encoder/decoder
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let customRequest = try HTTPRequest.post(url, body: danny, encoder: encoder)

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    let createdAgain: RiderProfile = try await URLSession.shared.perform(customRequest, decoder: decoder)

    // For requests expecting no content (204, etc.)
    try await URLSession.shared.perform(.delete(url.appendingPathComponent("123")))

    _ = riders
    _ = created
    _ = createdAgain
}

func basicHTTPRequest() throws {
    let url = URL(string: "https://example.net/kittens")!

    // Basic GET request
    let request = HTTPRequest.get(url)

    // GET request with query parameters
    let getRequest = HTTPRequest.get(url, parameters: ["page": 1, "limit": 10])

    // DELETE request with query parameters
    let deleteRequest = HTTPRequest.delete(url, parameters: ["confirm": "true"])

    _ = request
    _ = getRequest
    _ = deleteRequest
}

func moreComplicatedPOSTRequest() throws {
    let url = URL(string: "https://example.net/band")!
    let params = ["email": "fatmike@example.net", "password": "LinoleumSupportsMyHead"]

    // POST with JSON body
    let jsonRequest = HTTPRequest.postJSON(url, body: params)

    // POST with form-encoded body
    let formRequest = HTTPRequest.postForm(url, parameters: params)

    // POST with multipart body
    let multipartRequest = HTTPRequest.postMultipart(url, parts: [.text("all day", name: "album")])

    _ = jsonRequest
    _ = formRequest
    _ = multipartRequest
}

func requestBuilderExample() throws {
    let url = URL(string: "https://example.net/band")!
    let params = ["email": "fatmike@example.net", "password": "LinoleumSupportsMyHead"]
    let request = HTTPRequest.postJSON(url, body: params)
    let urlRequest = try RequestBuilder.build(request: request)
    _ = urlRequest
}

func moreCodableExamples() throws {
    struct Artist: Codable {
        let name: String
        let email: String
        let genre: String
    }

    let url = URL(string: "https://beats.example.net/artists")!
    let artist = Artist(name: "Trent Reznor", email: "trent@example.net", genre: "Industrial")

    // POST with Codable body
    let postRequest = try HTTPRequest.post(url, body: artist)

    // PUT with Codable body
    let putRequest = try HTTPRequest.put(url, body: artist)

    // PATCH with Codable body
    let patchRequest = try HTTPRequest.patch(url, body: artist)

    // Custom encoder for different JSON formatting
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    let customRequest = try HTTPRequest.post(url, body: artist, encoder: encoder)

    _ = postRequest
    _ = putRequest  
    _ = patchRequest
    _ = customRequest
}

func formEncoderExample() {
    let body = FormEncoder.encode(["email": "trent@example.net", "password": "CloserToGod"])
    _ = body
}

func multipartFormExample() throws {
    let avatarData = Data("fake image data".utf8)  // Simplified for compilation
    let encoder = MultipartFormEncoder()
    let body = try encoder.encodeData(parts: [
        .text("chali@example.net", name: "email"),
        .text("QualityControl", name: "password"),
        .data(avatarData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
    ])
    _ = body
}

func completeExample() async throws {
    struct ArtistProfile: Codable {
        let name: String
        let email: String
        let genre: String
    }

    struct UpdateProfileRequest: Codable {
        let name: String
        let email: String
        let genre: String
    }

    func updateProfile(name: String, email: String, genre: String) async throws -> ArtistProfile {
        let url = URL(string: "https://beats.example.net/profile")!
        let updateRequest = UpdateProfileRequest(name: name, email: email, genre: genre)
        
        // Use Codable body instead of dictionary
        let request = try HTTPRequest.put(url, body: updateRequest)
        
        // URLSession extension handles status checking and JSON decoding
        return try await URLSession.shared.perform(request)
    }

    // For varied data structures, dictionaries are still available as an escape hatch:
    func updateProfileWithDictionary(fields: [String: String]) async throws -> ArtistProfile {
        let url = URL(string: "https://beats.example.net/profile")!
        let request = HTTPRequest.putJSON(url, body: fields)
        return try await URLSession.shared.perform(request)
    }

    _ = updateProfile
    _ = updateProfileWithDictionary
}

func httpResponseExample() throws {
    let url = URL(string: "https://example.net/test")!
    let urlRequest = URLRequest(url: url)
    
    let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
        let httpResponse = HTTPResponse(response: response, data: data, error: error)

        switch httpResponse {
        case let .success(httpURLResponse, data):
            print("Success: \(httpURLResponse.statusCode)")
            if let data = data {
                print("Response: \(String(data: data, encoding: .utf8) ?? "")")
            }
        case let .failure(error, httpURLResponse, _):
            print("Failed: \(error)")
            if let httpURLResponse = httpURLResponse {
                print("Status: \(httpURLResponse.statusCode)")
            }
        }
    }
    _ = task
}

func multipartFileStreamingExample() throws {
    let encoder = MultipartFormEncoder()
    let avatarData = Data("fake image data".utf8)
    
    let body = try encoder.encodeFile(parts: [
        .text("chali@example.net", name: "email"),
        .text("QualityControl", name: "password"),
        .data(avatarData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
    ])
    defer { _ = body.cleanup() }

    var request = URLRequest(url: URL(string: "https://example.net/accounts")!)
    request.httpMethod = "POST"
    request.httpBodyStream = InputStream(url: body.url)
    request.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
    request.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")

    _ = request
}

func errorHandlingExample() throws {
    func handleErrors() async {
        do {
            let url = URL(string: "https://example.net/test")!
            let request = HTTPRequest.get(url)
            let response: [String] = try await URLSession.shared.perform(request)

            _ = response
        } catch let httpError as HTTPError {
            switch httpError {
            case let .failure(statusCode, data, _):
                print("HTTP \(statusCode) error: \(String(data: data, encoding: .utf8) ?? "No body")")
            case .invalidResponse:
                print("Invalid response from server")
            }
        } catch is DecodingError {
            print("Failed to decode response JSON")
        } catch {
            print("Network error: \(error)")
        }
    }
    
    _ = handleErrors
}

func migrationGuideExamples() throws {
    let url = URL(string: "https://example.net/test")!
    
    // Explicit methods for different encodings
    let jsonRequest = HTTPRequest.postJSON(url, body: ["key": "value"])
    let formRequest = HTTPRequest.putForm(url, parameters: ["key": "value"])
    
    // Multipart convenience methods
    let multipartRequest = HTTPRequest.postMultipart(url, parts: [.text("value", name: "field")])
    
    // Codable support
    struct Artist: Codable {
        let name: String
        let genre: String
    }
    let codableRequest = try HTTPRequest.post(url, body: Artist(name: "Trent Reznor", genre: "Industrial"))
    
    _ = jsonRequest
    _ = formRequest
    _ = multipartRequest
    _ = codableRequest
}

func additionalHTTPRequestExamples() throws {
    // Examples from HTTPRequest documentation
    
    // GET request with query parameters
    let getRequest = HTTPRequest.get(
        URL(string: "https://api.example.net/users")!,
        parameters: ["page": "1", "limit": "10"]
    )

    // POST with JSON body
    let jsonRequest = HTTPRequest.postJSON(
        URL(string: "https://api.example.net/users")!,
        body: ["name": "Chali 2na", "email": "chali@example.net"]
    )

    // DELETE with query parameters
    let deleteRequest = HTTPRequest.delete(
        URL(string: "https://api.example.net/users/123")!,
        parameters: ["confirm": "true"]
    )

    // Multipart form with file upload
    let uploadURL = URL(string: "https://api.example.net/upload")!
    let imageData = Data("fake image".utf8)
    let multipartRequest = HTTPRequest.postMultipart(uploadURL, parts: [
        .text("Trent Reznor", name: "name"),
        .data(imageData, name: "avatar", type: "image/jpeg", filename: "avatar.jpg")
    ])

    // File streaming for large request bodies
    let tempFile = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.txt")
    try "test content".write(to: tempFile, atomically: true, encoding: .utf8)
    let fileRequest = HTTPRequest.postFile(
        URL(string: "https://api.example.net/upload")!,
        fileURL: tempFile
    )

    // Custom content types like XML
    let xmlData = "<request><artist>Nine Inch Nails</artist></request>".data(using: .utf8)!
    let xmlRequest = HTTPRequest.post(
        URL(string: "https://api.example.net/music")!,
        data: xmlData,
        contentType: .xml
    )

    _ = getRequest
    _ = jsonRequest
    _ = deleteRequest
    _ = multipartRequest
    _ = fileRequest
    _ = xmlRequest
}
