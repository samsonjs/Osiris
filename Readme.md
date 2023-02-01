# Osiris

A multipart form encoder for Swift, as well as some other utilities that make
working with HTTP a bit simpler and more flexible.

# Installation

Copy the files you want to use into your project, and then customize them to suit your needs.

# Multipart Form Encoding

Create an encoder and then add parts to it as needed:

```Swift
let avatarData = UIImage(from: somewhere).jpegData(compressionQuality: 1)
let encoder = MultipartFormEncoder()
let body = try encoder.encodeData(parts: [
    .text("somebody@example.com", name: "email"),
    .text("secret", name: "password"),
    .data(Data(), name: "avatar", type: "image/jpeg", filename: "avatar.jpg"),
])
```

The form can be encoded as `Data` in memory, or to a file. There's a hard limit of 50 MB on encoding to memory but in practice you probably never want to go that high purely in memory. If you're adding any kind of image or video file then it's probably better to stream to a file.

```Swift
let body = try encoder.encodeFile(parts: [/* ... */])
var request = URLRequest(url: URL(string: "https://example.com/accounts")!)
request.httpMethod = "POST"
request.httpBodyStream = InputStream(url: body.url)
request.addValue(body.contentType, forHTTPHeaderField: "Content-Type")
request.addValue("\(body.contentLength)", forHTTPHeaderField: "Content-Length")
// ... whatever you normally do with requests
```

# HTTPRequest

Basic usage:

```Swift
let url = URL(string: "https://example.com")!
let request = HTTPRequest(method: .get, url: url)
```

Fancier usage:

```Swift
let url = URL(string: "https://example.com")!
let params = ["email" : "someone@example.com", "password" : "secret"]
let request = HTTPRequest(method: .post, url: url, contentType: .json, parameters: params)
request.addHeader(name: "x-custom", value: "42")
request.addMultipartJPEG(name: "avatar", image: UIImage(), quality: 1, filename: "avatar.jpg")
```

You can build a `URLRequest` from an `HTTPRequest` instance using `RequestBuilder`. Or make your own builder.

# HTTPResponse

This enum makes sense of the 3 parameters of `URLSession`'s completion block. Its initializer takes in the optional `URLResponse`, `Data`, and `Error` values and determines if the request succeeded or failed, taking the HTTP status code into account. 200-level statuses are successes and anything else is a failure.

The success case has two associated values: `HTTPURLResponse` and `Data?`, while the failure case has three associated values: `Error`, `HTTPURLResponse`, and `Data?`.

Some properties are exposed for convenience:

- `data`: the optional body data returned by the server.

- `status`: the HTTP status code returned by the server, or 0 if the request itself failed, e.g. if the server cannot be reached.

- `headers`: a dictionary of headers.

- `bodyString`: the response body as a `String`. This is an empty string if the body is empty or there was an error decoding it as UTF8.

- `dictionaryFromJSON`: the decoded body for JSON responses. This is an empty dictionary if the body is empty or there was an error decoding it as a JSON dictionary.

- `underlyingResponse`: the `HTTPURLResponse` in case you need to dive in.

# RequestBuilder

This class takes in an `HTTPRequest` instance and turns it into a `URLRequest` for use with `URLSession`.

Usage:

```Swift
let urlRequest: URLRequest
do {
    urlRequest = try RequestBuilder.build(request: request)
}
catch {
    log.error("Invalid request \(request): \(error)")
    return
}
// ... do something with urlRequest
```

It encodes multipart requests in memory, so you'll need to change it or make your own builder for advanced functionality like encoding multipart forms to disk instead.

# FormEncoder

This was lifted from [Alamofire][], but with some minor changes.

```Swift
let body = FormEncoder.encode(["email" : "someone@example.com", "password" : "secret"])
// => "email=someone%40example.com&password=secret"
```

[Alamofire]: https://github.com/Alamofire/Alamofire

# Service: Putting it all Together

Take a look at `Service.swift` to see how it can all come together. Grafting your specific service API onto the primitives shown there is an exercise. In 1SE we're just adding methods to `Service` for each specific call, but you could keep them separate instead if you prefer that.

I don't recommend you use `Service` as shown here, but maybe use it as a jumping off point for something that makes sense to you for your specific application.

# Credits

Mostly created by Sami Samhuri for [1SE][]. `FormEncoder.swift` was lifted from [Alamofire][].

[1SE]: https://1se.co

# License

Copyright © 2017 [1 Second Everyday][1SE]. All rights reserved.

Released under the terms of the MIT license:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
