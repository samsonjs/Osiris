# Changelog

## [2.1.0] - Unreleased

### Added
- Codable body support in HTTPRequest factory methods: `post(body:encoder:)`, `put(body:encoder:)`, `patch(body:encoder:)`
- URLSession extensions for automatic JSON decoding with custom decoder support
- HTTPError type with status code and response body for better error debugging
- Multipart convenience methods: `postMultipart()`, `putMultipart()`, `patchMultipart()`
- Explicit body encoding methods with clear naming: `postJSON()`, `postForm()`, etc.
- Query parameter support for GET and DELETE requests - parameters are now properly encoded as query strings

### Removed
- `CodableRequest<Response>` - Replaced with direct HTTPRequest Codable support for simplicity

### Changed
- Minimum deployment targets changed to ones that actually build: iOS 16.0 and macOS 13.0
- `HTTPRequest` now uses `HTTPRequestBody` enum internally for better type safety
- GET and DELETE requests now properly encode parameters as query strings instead of ignoring them
- Added validation to prevent GET/DELETE requests from having request bodies

### Deprecated
- `HTTPRequest.post(url:contentType:parameters:)` - Use `postJSON()` or `postForm()` instead
- `HTTPRequest.put(url:contentType:parameters:)` - Use `putJSON()` or `putForm()` instead
- `HTTPRequest.patch(url:contentType:parameters:)` - Use `patchJSON()` or `patchForm()` instead
- Direct access to `HTTPRequest.parameters` property
- Direct access to `HTTPRequest.parts` property

### Migration Guide
- Swap `HTTPRequest.post(url, contentType: .json, parameters: params)` for `HTTPRequest.postJSON(url, body: params)`
- Swap `HTTPRequest.post(url, contentType: .formEncoded, parameters: params)` for `HTTPRequest.postForm(url, parameters: params)`
- Swap `HTTPRequest.put(url, contentType: .json, parameters: params)` for `HTTPRequest.putJSON(url, body: params)`
- Swap `HTTPRequest.patch(url, contentType: .json, parameters: params)` for `HTTPRequest.patchJSON(url, body: params)`
- For multipart requests, use `HTTPRequest.postMultipart(url, parts: parts)` instead of setting the `parts` property directly

[2.1.0]: https://github.com/samsonjs/Osiris/compare/2.0.1...main

## [2.0.1] - 2025-06-15

### Fixed
- GET and DELETE requests with empty parameters no longer include unnecessary question mark in URL

[2.0.1]: https://github.com/samsonjs/Osiris/compare/2.0.0...2.0.1

## [2.0.0] - 2025-06-15

### Added
- **GET/DELETE query parameter support** - Parameters are now automatically encoded as query strings for GET and DELETE requests
- **Enhanced error types** with localized descriptions and failure reasons
- **Comprehensive test coverage**

### Enhanced
- **Public API** - All types and methods now have proper public access modifiers
- **Error handling** - More specific error cases with `LocalizedError` conformance
- **Debugging support** - All types now conform to `CustomStringConvertible` with idiomatic descriptions for better OSLog output

[2.0.0]: https://github.com/samsonjs/Osiris/compare/1.0.0...2.0.0

## [1.0.0] - 2017-07-28

### Added
- Initial release with multipart form encoding
- HTTPRequest and HTTPResponse abstractions
- RequestBuilder for URLRequest conversion
- FormEncoder for URL-encoded forms

[1.0.0]: https://github.com/samsonjs/Osiris/releases/tag/1.0.0
