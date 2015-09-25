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
import Decodable

/// Handler called when an OAuth authorization request has completed.
public typealias AuthorizationCompletionHandler = Response -> Void
typealias ResponseParser = (NSURLResponse, NSData) throws -> Response?

/// The entry point into perform OAuth requests in this framework.
public class OAuth2 {
    private let requestProcessor: URLRequestProcessor
    
    /// Initializes a new OAuth object.
    /// - Parameters:
    ///   - requestProcessor: The processor that will be used to make URL requests.
    public init(requestProcessor: URLRequestProcessor? = nil) {
        self.requestProcessor = requestProcessor ?? NSURLSessionRequestProcessor()
    }
    
    /// Performs an OAuth Client Credentials request, calling a completion handler when the
    /// request has finished.
    /// - Parameters:
    ///   - request: The request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). May be set to `nil`, in which case the caller will receive
    ///                 no notification of completion.
    ///                 The caller must not make any assumptions about which dispatch queue the completion will be
    ///                 called on.
    ///     - Parameters:
    ///       - response: The `Response` representing the result of the authentication.
    public func authorize(request: ClientCredentialsRequest, completion: AuthorizationCompletionHandler? = nil) {
        guard let url = request.authorizationURL else {
            completion?(.Failure(failure: .WithReason(reason: "authorization URL must be set for Client Credentials request")))
            return
        }
        guard let urlRequest = request.toNSURLRequestForURL(url) else {
            completion?(.Failure(failure: .WithReason(reason: "failed to create request for URL \(url)")))
            return
        }

        performUrlRequest(urlRequest, completion: completion) { urlResponse, data in
            if let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String,
               let jsonObject = jsonString.jsonObject {
                let authorizationData = try AuthorizationData.decode(jsonObject)
                return .Success(data: authorizationData)
            } else {
                return .Failure(failure: .WithReason(reason: "failed to parse JSON authorization response"))
            }
        }
    }
    
    private func performUrlRequest(urlRequest: NSURLRequest, completion: AuthorizationCompletionHandler?, responseParser: ResponseParser) {
        /// TODO: user hook for modifying URL request before it is sent.
        logRequest(urlRequest)
        requestProcessor.process(urlRequest) { urlResponse, error, data in
            if error != nil {
                completion?(.Failure(failure: .WithError(error: error!)))
            } else if data != nil && urlResponse != nil {
                self.logResponse(urlResponse as? NSHTTPURLResponse, bodyData: data)
                
                guard let statusCode = (urlResponse as? NSHTTPURLResponse)?.statusCode else {
                    completion?(.Failure(failure: .WithReason(reason: "invalid resonse type: \(urlResponse)")))
                    return
                }
                if statusCode < 200 || statusCode > 299 {
                    completion?(.Failure(failure: .WithReason(reason: "server request failed with status \(statusCode)")))
                    return
                }
                do {
                    /// TODO: user hook for processing URL response and giving the thumbs up/down
                    if let response = try responseParser(urlResponse!, data!) {
                        completion?(response)
                    } else {
                        completion?(.Failure(failure: .WithReason(reason: "failed to parse response data")))
                    }
                } catch let error {
                    completion?(.Failure(failure: .WithReason(reason: "failed to parse response data: \(error)")))
                }
            } else {
                completion?(.Failure(failure: .WithReason(reason: "invalid response")))
            }
        }
    }
    
    private func logRequest(urlRequest: NSURLRequest) {
        print("\(urlRequest.HTTPMethod!) \(urlRequest.URL!)")
        if let headers = urlRequest.allHTTPHeaderFields {
            for (name, value) in headers {
                print("\(name): \(value)")
            }
        }
        if let bodyData = urlRequest.HTTPBody {
            if let bodyString = NSString(data: bodyData, encoding: NSUTF8StringEncoding) {
                print("\n\(bodyString)")
           } else {
                print("\n<\(bodyData.length) byte(s)>")
           }
        }
    }
    
    private func logResponse(urlResponse: NSHTTPURLResponse?, bodyData: NSData?) {
        let statusCode = urlResponse?.statusCode ?? 0
        print("HTTP \(statusCode) \(NSHTTPURLResponse.localizedStringForStatusCode(statusCode))")
        if let headers = urlResponse?.allHeaderFields {
            for (name, value) in headers {
                print("\(name): \(value)")
            }
        }
        if let data = bodyData {
            if let bodyString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                print("\n\(bodyString)")
            } else {
                print("\n<\(data.length) byte(s)>")
            }
        }
    }
}

extension AuthorizationData : Decodable {
    /// Decodes authorization data JSON into an `AuthorizationData` object.
    public static func decode(json: AnyObject) throws -> AuthorizationData {
        return try AuthorizationData(
            accessToken: json => "access_token",
            refreshToken: json =>? "refresh_token",
            expiresIn: json =>? "expires_in")
    }
}

extension String {
    /// A Base64 encoding of the UTF-8 bytes for this string.
    var base64Value: String? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)?
                   .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
    
    /// Attempts to parse this string as JSON and returns the parsed object if successful.
    var jsonObject: AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
}