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
        let handler = handlerForResponse(200, url: url, body: ["access_token" : accessToken].toJSONString())
        
        let request = ClientCredentialsRequest(url: url , clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request, authorizationHandler: handler) { response = $0 }
            finished()
        }

        assertSuccessfulWithToken(response, accessToken: accessToken)
    }
    
    func testServerReturnsUnauthorized() {
        let url = "http://nonexistent.com/authorization"
        let handler = handlerForResponse(401, url: url, body: "")
        
        let request = ClientCredentialsRequest(url: url , clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request, authorizationHandler: handler) { response = $0 }
            finished()
        }
        
        assertFailedWithReason(response)
    }
    
    // - MARK: test helpers
    
    private func handlerForResponse(statusCode: Int, url urlString: String, body: String, headers: [String: String] = [:]) -> URLRequestHandler {
        let url = NSURL(string: urlString)!
        return { request, responseHandler in
            responseHandler(
                NSHTTPURLResponse(URL: url, statusCode: statusCode, HTTPVersion: "HTTP/1.1", headerFields: headers),
                nil,
                body.dataUsingEncoding(NSUTF8StringEncoding))
        }
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

protocol NSStringConvertible {
    var nsString : NSString { get }
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

// What a hack to get toJson() only on Dictionary<String, String> :(

extension String : NSStringConvertible {
    public var nsString: NSString {
        return NSString(string: self)
    }
}

extension Dictionary where Key: NSStringConvertible, Value: NSStringConvertible {
    func toJSONString() -> String {
        var dict: [NSString : NSString] = [:]
        for (name, value) in self {
            dict[name.nsString] = value.nsString
        }
        let data = try! NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions(rawValue: 0))
        return NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    }
}