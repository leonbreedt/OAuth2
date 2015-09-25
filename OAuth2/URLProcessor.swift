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
import UIKit

/// Defines a response handler for a URL request processor, which should be called
/// when the response has completed.
public typealias URLResponseHandler = (NSURLResponse?, NSError?, NSData?) -> Void

/// Represents something that is able to make URL requests.
public protocol URLRequestProcessor {
    /// Sends a `NSURLRequest` over the wire.
    /// - Parameters:
    ///   - request: The URL request to send.
    ///   - completion: If not `nil`, the response handler to call when the request has completed.
    func process(request: NSURLRequest, completion: URLResponseHandler?)
}

/// Makes requests using `NSURLSession` data tasks.
public class NSURLSessionRequestProcessor : URLRequestProcessor {
    let session: NSURLSession
    
    init(session: NSURLSession? = nil) {
        self.session = session ?? {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration)
        }()
    }
    
    public func process(request: NSURLRequest, completion: URLResponseHandler? = nil) {
        let dataTask = session.dataTaskWithRequest(request) { data, urlResponse, error in
            completion?(urlResponse, error, data)
        }
        dataTask.resume()
    }
}