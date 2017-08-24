# Osiris

A multipart form encoder for Swift.

# Installation

Copy the file [`MultipartFormEncoder.swift`][code] into your project.

[code]: https://github.com/1SecondEveryday/Osiris/blob/master/MultipartFormEncoder.swift

# Usage

Create an encoder and then add parts to it as needed:

```Swift
let encoder = MultipartFormEncoder()
try! encoder.addText(name: "email", text: "somebody@example.com")
try! encoder.addText(name: "password", text: "secret")
let avatarData = UIImageJPEGRepresentation(avatar, 1)!
encoder.addBinary(name: "avatar.jpg", contentType: "image/jpeg", data: avatarData)
```

You can encode the entire form as `Data` in memory if it's not very big:

```Swift
let encoded = try encoder.encodeToMemory()
var request = URLRequest(url: URL(string: "https://example.com/accounts")!)
request.httpMethod = "POST"
request.httpBody = encoded.body
request.addValue(encoded.contentType, forHTTPHeaderField: "Content-Type")
request.addValue("\(encoded.contentLength)", forHTTPHeaderField: "Content-Length")
// ... whatever you normally do with requests
```

For larger forms you can also stream the encoded form data directly to disk:

```Swift
let path = NSTemporaryDirectory().appending("/form.data")
let encoded = try encoder.encodeToDisk(path: path)
var request = URLRequest(url: URL(string: "https://example.com/accounts")!)
request.httpMethod = "POST"
request.addValue(encoded.contentType, forHTTPHeaderField: "Content-Type")
request.addValue("\(encoded.contentLength)", forHTTPHeaderField: "Content-Length")
let task = URLSession.shared.uploadTask(with: request, fromFile: encoded.bodyFileURL) { maybeData, maybeResponse, maybeError in

}
task.resume()

```

You can create and add your own parts using the `MultipartFormEncoder.Part` struct and `MultipartFormEncoder.addPart(_ part: Part)`.

# Credits

Created by Sami Samhuri for [1SE][].

[1SE]: http://1se.co

# License

Copyright © 2017 [1 Second Everyday][1SE]. All rights reserved.

Released under the terms of the MIT license:

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
