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

public typealias URLResponseHandler = (NSURLResponse?, NSError?, NSData?) -> Void

public protocol URLRequestProcessor {
    func process(request: NSURLRequest, completion: URLResponseHandler?)
}

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