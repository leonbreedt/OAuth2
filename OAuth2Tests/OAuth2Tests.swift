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

let authorizationURL = "http://nonexistent.com/authorization"
let tokenURL = "http://nonexistent.com/token"
let clientId = "test-client-id"
let clientSecret = "test-client-secret"
let accessToken = "open sesame"

class OAuth2Tests: XCTestCase {
    override func setUp() {
        OAuth2.urlRequestHook = testURLRequest
        OAuth2.webViewRequestHook = testWebViewRequest
    }
    
    func testClientCredentialsSuccessfulAuth() {
        setUpURLResponse(200, url: authorizationURL, body: ["access_token": accessToken].toJSONString())
        
        let request = ClientCredentialsRequest(authorizationURL: authorizationURL, clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }

        switch response! {
        case .Success(let data):
            XCTAssertEqual(accessToken, data.accessToken)
            break
        default:
            XCTFail("expected request to succeed, but was \(response) instead")
        }
    }
    
    func testClientCredentialsFailedAuth() {
        setUpURLResponse(400, url: authorizationURL, body: ["error": "access_denied", "error_description": "internal error"].toJSONString())
        
        let request = ClientCredentialsRequest(authorizationURL: authorizationURL, clientId: clientId, clientSecret: clientSecret)!
        var response: Response!
        performOAuthRequest("Client Credentials request") { finished in
            OAuth2.authorize(request) { response = $0 }
            finished()
        }
        
        switch response! {
        case .Failure(let error):
            switch error {
            case AuthorizationFailure.OAuthAccessDenied(let description):
                XCTAssertEqual("internal error", description)
            default:
                XCTFail("expected request to fail with OAuthAccessDenied, but was \(error) instead")
            }
        default:
            XCTFail("expected request to fail with OAuthAccessDenied, but was \(response) instead")
        }
    }

    // - MARK: test helpers
    
    private var handleURLRequest: (OAuth2.URLRequestCompletionHandler -> Void)! = nil
    private var handleWebViewRequest: (OAuth2.WebViewRequestCompletionHandler -> Void)! = nil
    
    private func testURLRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, ErrorType?) -> Void) {
        assert(handleURLRequest != nil)
        handleURLRequest(completionHandler)
    }
    
    private func testWebViewRequest(request: NSURLRequest, redirectionURL: NSURL, completionHandler: ([String: String]?, ErrorType?) -> Void) {
        assert(handleWebViewRequest != nil)
        handleWebViewRequest(completionHandler)
    }
    
    private func setUpURLResponse(statusCode: Int, url urlString: String, body: String, headers: [String: String] = [:]) {
        let url = NSURL(string: urlString)!
        handleURLRequest = { completion in
            completion(
                body.dataUsingEncoding(NSUTF8StringEncoding),
                NSHTTPURLResponse(URL: url, statusCode: statusCode, HTTPVersion: "HTTP/1.1", headerFields: headers),
                nil)
        }
    }
}

private protocol NSStringConvertible {
    var nsString : NSString { get }
}

private extension XCTestCase {
    func performOAuthRequest(description: String, timeout: NSTimeInterval = 5.0, callback: (() -> Void) -> Void) {
        let expectation = expectationWithDescription(description)
        callback(expectation.fulfill)
        waitForExpectationsWithTimeout(timeout, handler: nil)
   }
}

extension String : NSStringConvertible {
    public var nsString: NSString {
        return NSString(string: self)
    }
}

private extension Dictionary where Key: NSStringConvertible, Value: NSStringConvertible {
    func toJSONString() -> String {
        var dict: [NSString : NSString] = [:]
        for (name, value) in self {
            dict[name.nsString] = value.nsString
        }
        let data = try! NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions(rawValue: 0))
        return NSString(data: data, encoding: NSUTF8StringEncoding) as! String
    }
}