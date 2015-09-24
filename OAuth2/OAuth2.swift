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

/// Handler called when an OAuth authentication request has completed.
public typealias AuthenticationCompletionHandler = Response -> Void

/// The entry point into perform OAuth requests in this framework.
public class OAuth2 {
    private let requestProcessor: URLRequestProcessor
    
    /// Initializes a new OAuth object.
    /// - Parameters:
    ///   - requestProcessor: The processor that will be used to make URL requests.
    public init(requestProcessor: URLRequestProcessor? = nil) {
        self.requestProcessor = requestProcessor ?? NSURLSessionRequestProcessor()
    }
    
    /// Performs an OAuth authentication request, calling a completion handler when the
    /// request has finished.
    /// - Parameters:
    ///   - request: An OAuth request to execute.
    ///   - completion: The `AuthenticationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). May be set to `nil`, in which case the caller will receive
    ///                 no notification of completion.
    ///                 The caller must not make any assumptions about which dispatch queue the completion will be
    ///                 called on.
    ///     - Parameters:
    ///       - response: The `Response` representing the result of the authentication.
    public func authenticate(request: Request, completion: AuthenticationCompletionHandler? = nil) {
        guard let url = request.initialUrl else {
            completion?(.Failure(failure: .WithReason(reason: "invalid URL for request")))
            return
        }
        guard let urlRequest = request.toNSURLRequest(url) else {
            completion?(.Failure(failure: .WithReason(reason: "failed to create request for URL \(url)")))
            return
        }
        
        // TODO: user hook for modifying request before it is sent.
        
        requestProcessor.process(urlRequest) { urlResponse, error, data in
            if error != nil {
                completion?(.Failure(failure: .WithError(error: error!)))
            } else if data != nil && urlResponse != nil {
                if let jsonString = NSString(data: data!, encoding: NSUTF8StringEncoding) as? String,
                    let jsonObject = jsonString.jsonObject,
                    let response = try? request.parseInitialJsonResponse(jsonObject) {
                        
                        // TODO: log response
                        // TODO: user hook for extracting token and refresh token from response
                        // TODO: parse JSON if no user hook
                        print("response: \(response)")
                        
                        completion?(response)
                } else {
                    completion?(.Failure(failure: .WithReason(reason: "failed to parse response data")))
                }
            } else {
                completion?(.Failure(failure: .WithReason(reason: "invalid response")))
            }
        }
    }
}

/// Represents an error that occured while attempting to parse a server response.
enum ResponseParseError : ErrorType {
    case UnsupportedRequestType
}

extension Request {
    /// The initial URL to connect to for this request.
    var initialUrl: NSURL? {
        switch self {
        case let r as ClientCredentialsRequest: return r.authorizationURL
        default: return nil
        }
    }
    
    /// Parses the initial JSON response for this request.
    func parseInitialJsonResponse(jsonObject: AnyObject) throws -> Response {
        switch self {
        case _ as ClientCredentialsRequest: return .Success(data: try AuthenticationData.decode(jsonObject))
        default: throw ResponseParseError.UnsupportedRequestType
        }
    }
}

extension AuthenticationData : Decodable {
    /// Decodes authentication data JSON into an `AuthenticationData` object.
    public static func decode(json: AnyObject) throws -> AuthenticationData {
        return try AuthenticationData(
            accessToken: json => "access_token",
            refreshToken: json => "refresh_token",
            expiresIn: json => "expires_in")
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