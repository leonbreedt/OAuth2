//
// OAuth2
// Copyright (C) 2015 Leon Breedt
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import XCTest

@testable import OAuth2

let clientId = "test-client-id"
let clientSecret = "test-client-secret"
let accessToken = "open sesame"

class OAuth2Tests: XCTestCase, URLRequestProcessor {
    
    var oauth: OAuth2!
    var nextResponse: NSURLResponse?
    var nextError: NSError?
    var nextData: NSData?
    
    override func setUp() {
        super.setUp()
        oauth = OAuth2(requestProcessor: self)
    }
    
    func testClientCredentialsSuccessfulAuth() {
        let url = "http://nonexistent.com/authorization"
        setOkResponse(url: url, body: ["access_token" : accessToken].toJson())
        
        let request = ClientCredentialsRequest(url: url , clientId: clientId, clientSecret: clientSecret)!
        let response = runRequest(request)

        assertSuccessfulWithToken(response, accessToken: accessToken)
    }
    
    // - MARK: test helpers
    
    func process(request: NSURLRequest, completion: URLResponseHandler?) {
        completion?(nextResponse, nextError, nextData)
        nextResponse = nil
        nextError = nil
        nextData = nil
    }
    
    private func setOkResponse(url urlString: String, body: String, headers: [String: String] = [:]) {
        let url = NSURL(string: urlString)!
        nextResponse = NSHTTPURLResponse(URL: url, statusCode: 200, HTTPVersion: "HTTP/1.1", headerFields: headers)
        nextError = nil
        nextData = body.dataUsingEncoding(NSUTF8StringEncoding)
    }
    
    private func runRequest(request: Request) -> Response {
        let expectation = expectationWithDescription("OAuth request")
        var response: Response? = nil
        oauth.authenticate(request) {
            response = $0
            expectation.fulfill()
        }
        waitForExpectationsWithTimeout(5.0, handler: nil)
        return response!
    }
    
    private func assertSuccessfulWithToken(response: Response?, accessToken: String, file: String = __FILE__, line: UInt = __LINE__) {
        XCTAssertNotNil(response, file: file, line: line)
        switch (response!) {
        case .Failure(let reason):
            switch (reason) {
            case .WithError(let error):
                XCTFail("Expected response to be successful, but response failed with NSError: \(error)", file: file, line: line)
            case .WithReason(let reason):
                XCTFail("Expected response to be successful, but response failed with reason: \(reason)", file: file, line: line)
            }
        case .Success(let data):
            if data.accessToken != accessToken {
                recordFailureWithDescription("assertSuccessfulWithToken failed: token \"\(data.accessToken)\" is not equal to \"\(accessToken)\"", inFile: file, atLine: line, expected: false)
            }
        }
    }
}

extension String : CustomStringConvertible {
    public var description: String {
        return self
    }
}

extension Dictionary where Key: CustomStringConvertible, Value: CustomStringConvertible {
    func toJson() -> String {
        // What a hack to get toJson() only on Dictionary<String, String>. WTF, Apple.
        var dict: [NSString : NSString] = [:]
        for (name, value) in self {
            dict[NSString(string: name.description)] = NSString(string: value.description)
        }
        let data = try! NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions(rawValue: 0))
        return NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    }
}