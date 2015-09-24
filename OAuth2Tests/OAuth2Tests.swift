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

class OAuth2Tests: XCTestCase, URLRequestProcessor {
    var nextResponse: NSURLResponse?
    var nextError: NSError?
    var nextData: NSData?
    
    func testClientCredentialsSuccessfulAuth() {
        nextResponse = NSURLResponse()
        nextError = nil
        nextData = "{\"access_token\": \"open sesame\"}".dataUsingEncoding(NSUTF8StringEncoding)
        
        var response: Response? = nil
        let oauth = OAuth2(requestProcessor: self)
        let request = ClientCredentialsRequest(url: NSURL(string: "http://localhost/test")!, clientId: "client-id", clientSecret: "client-secret")
        let expectation = expectationWithDescription("OAuth request")
        oauth.authenticate(request) { r in
            expectation.fulfill()
            response = r
        }
        waitForExpectationsWithTimeout(10.0, handler: nil)
        
        assertSuccessfulResponse(response)
    }
    
    func process(request: NSURLRequest, completion: URLResponseHandler?) {
        completion?(nextResponse, nextError, nextData)
        nextResponse = nil
        nextError = nil
        nextData = nil
    }
    
    private func assertSuccessfulResponse(response: Response?, file: String = __FILE__, line: UInt = __LINE__) {
        XCTAssertNotNil(response, file: file, line: line)
        switch (response!) {
        case .Failure(let reason):
            switch (reason) {
            case .WithError(let error): XCTFail("Expected response to be successful, but response failed with NSError: \(error)", file: file, line: line)
            case .WithReason(let reason): XCTFail("Expected response to be successful, but response failed with reason: \(reason)", file: file, line: line)
            }
        default: break
        }
    }
}
