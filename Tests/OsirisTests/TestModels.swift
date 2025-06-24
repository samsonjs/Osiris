//
// Created by Sami Samhuri on 2025-06-23.
// Copyright © 2025 Sami Samhuri. All rights reserved.
// Released under the terms of the MIT license.
//

import Foundation

// MARK: - Rider Models

struct RiderProfile: Codable, Equatable {
    let id: Int
    let name: String
    let email: String
    let bike: String
}

struct CreateRiderRequest: Codable {
    let name: String
    let email: String
    let bike: String
}

// MARK: - Artist Models

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

// MARK: - Generic Test Models

struct TestResponse: Codable {
    let message: String
    let success: Bool
}

struct TestRequestData: Codable {
    let name: String
    let email: String
}