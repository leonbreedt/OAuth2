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

class OAuth2Tests: XCTestCase {
    
    func testClientCredentialsSuccessfulAuth() {
        let url = "http://nonexistent.com/authorization"
        let processor = processorForResponse(200, url: url, body: ["access_token" : accessToken].toJson())
        
        let request = ClientCredentialsRequest(url: url , clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request, urlProcessor: processor) { response = $0 }
            finished()
        }

        assertSuccessfulWithToken(response, accessToken: accessToken)
    }
    
    func testServerReturnsUnauthorized() {
        let url = "http://nonexistent.com/authorization"
        let processor = processorForResponse(401, url: url, body: "")
        
        let request = ClientCredentialsRequest(url: url , clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request, urlProcessor: processor) { response = $0 }
            finished()
        }
        
        assertFailedWithReason(response)
    }
    
    // - MARK: test helpers
    
    private func processorForResponse(statusCode: Int, url urlString: String, body: String, headers: [String: String] = [:]) -> URLRequestProcessor {
        let url = NSURL(string: urlString)!
        let processor = TestRequestProcessor()
        processor.response = NSHTTPURLResponse(URL: url, statusCode: statusCode, HTTPVersion: "HTTP/1.1", headerFields: headers)
        processor.error = nil
        processor.data = body.dataUsingEncoding(NSUTF8StringEncoding)
        return processor
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

    private func assertFailedWithReason(response: Response?, file: String = __FILE__, line: UInt = __LINE__) {
        XCTAssertNotNil(response, file: file, line: line)
        switch (response!) {
        case .Failure(let reason):
            switch (reason) {
            case .WithError(let error):
                recordFailureWithDescription("assertFailedWithReason expected response to have a reason, but had an error instead: \(error)", inFile: file, atLine: line, expected: false)
            case .WithReason:
                return
            }
        case .Success:
            recordFailureWithDescription("assertFailedWithReason expected response to fail, but was successful instead", inFile: file, atLine: line, expected: false)
        }
    }
}

class TestRequestProcessor : URLRequestProcessor {
    var response: NSURLResponse?
    var error: NSError?
    var data: NSData?
    
    func process(request: NSURLRequest, completion: URLResponseHandler?) {
        completion?(response, error, data)
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

typealias OAuthRequestCompleted = () -> Void
typealias OAuthRequestCallback = OAuthRequestCompleted -> Void

extension XCTestCase {
    func performOAuthRequest(description: String, timeout: NSTimeInterval = 5.0, callback: OAuthRequestCallback) {
        let expectation = expectationWithDescription(description)
        callback(expectation.fulfill)
        waitForExpectationsWithTimeout(timeout, handler: nil)
   }
}