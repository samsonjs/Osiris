# Changelog

## [2.0.1] - 2025-06-15

### Fixed
- GET and DELETE requests with empty parameters no longer include unnecessary question mark in URL

[2.0.1]: https://github.com/samsonjs/Osiris/compare/2.0.0...main

## [2.0.0] - 2025-06-15

### Added
- **GET/DELETE query parameter support** - Parameters are now automatically encoded as query strings for GET and DELETE requests
- **Enhanced error types** with localized descriptions and failure reasons
- **Header convenience method** `addHeader(name:value:)` on `HTTPRequest`
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
