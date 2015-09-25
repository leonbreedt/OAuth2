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

/// The entry point into performing OAuth requests in this framework.
public class OAuth2 {
    /// Performs an OAuth `authorization_code` flow, calling a completion handler when the request is finished.
    /// Will redirect the user to the configured `UserAgent` to perform the authentication. The default user agent
    /// is a modally displayed `OAuthAuthorizationViewController` based implementation, but this can be replaced
    /// by specifying the `urlProcessor` parameter.
    /// - Parameters:
    ///   - request: The request to perform.
    ///   - urlProcessor: The URL processor to use. If not specified, a default implementation will be used.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). May be set to `nil`, in which case the caller will receive
    ///                 no notification of completion.
    ///                 The caller must not make any assumptions about which dispatch queue the completion will be
    ///                 called on.
    public static func authorize(
        request: AuthorizationCodeRequest,
        urlProcessor: URLRequestProcessor? = nil,
        completion: AuthorizationCompletionHandler? = nil)
    {
        guard let authorizationURL = request.authorizationURL else {
            completion?(.Failure(failure: .WithReason(reason: "authorization URL must be set for Authorization Code request")))
            return
        }
        guard let tokenURL = request.tokenURL else {
            completion?(.Failure(failure: .WithReason(reason: "token URL must be set for Authorization Code request")))
            return
        }
        
        //let processor = urlProcessor ?? WKWebViewRequestProcessor()
        
        print("authorizing using \(authorizationURL), calling web browser...")
        print("code received from web browser, calling token endpoint \(tokenURL)...")
        print("token received, calling completion")
    }
    
    /// Performs an OAuth `client_credentials` flow, calling a completion handler when the
    /// request has finished. This is a two-legged flow, and no user interaction is required.
    /// - Parameters:
    ///   - request: The request to perform.
    ///   - urlProcessor: The URL processor to use. If not specified, a default implementation will be used.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). May be set to `nil`, in which case the caller will receive
    ///                 no notification of completion.
    ///                 The caller must not make any assumptions about which dispatch queue the completion will be
    ///                 called on.
    ///     - Parameters:
    ///       - response: The `Response` representing the result of the authentication.
    public static func authorize(
        request: ClientCredentialsRequest,
        urlProcessor: URLRequestProcessor? = nil,
        completion: AuthorizationCompletionHandler? = nil)
    {
        guard let url = request.authorizationURL else {
            completion?(.Failure(failure: .WithReason(reason: "authorization URL must be set for Client Credentials request")))
            return
        }
        guard let urlRequest = request.toNSURLRequestForURL(url) else {
            completion?(.Failure(failure: .WithReason(reason: "failed to create request for URL \(url)")))
            return
        }
        
        let processor = urlProcessor ?? NSURLSessionRequestProcessor()

        performUrlRequest(urlRequest, urlProcessor: processor, completion: completion) { urlResponse, data in
            if let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) as? String,
               let jsonObject = jsonString.jsonObject {
                let authorizationData = try AuthorizationData.decode(jsonObject)
                return .Success(data: authorizationData)
            } else {
                return .Failure(failure: .WithReason(reason: "failed to parse JSON authorization response"))
            }
        }
    }
    
    // MARK: - Private
    
    private init() {
    }
    
    private typealias ResponseParser = (NSURLResponse, NSData) throws -> Response?
    
    private static func performUrlRequest(
        urlRequest: NSURLRequest,
        urlProcessor: URLRequestProcessor,
        completion: AuthorizationCompletionHandler?,
        responseParser: ResponseParser)
    {
        // TODO: user hook for modifying URL request before it is sent.
        logRequest(urlRequest)
        urlProcessor.process(urlRequest) { urlResponse, error, data in
            if error != nil {
                completion?(.Failure(failure: .WithError(error: error!)))
            } else if data != nil && urlResponse != nil {
                self.logResponse(urlResponse as? NSHTTPURLResponse, bodyData: data)
                
                guard let statusCode = (urlResponse as? NSHTTPURLResponse)?.statusCode else {
                    completion?(.Failure(failure: .WithReason(reason: "invalid resonse type: \(urlResponse)")))
                    return
                }
                // TODO: is there an enum somewhere where these codes are kept? what are the "official" codes that can
                //       be returned by the server according to RFC? what about redirection?
                if statusCode < 200 || statusCode > 299 {
                    completion?(.Failure(failure: .WithReason(reason: "server request failed with status \(statusCode)")))
                    return
                }
                do {
                    // TODO: user hook for processing URL response and giving the thumbs up/down
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
    
    private static func logRequest(urlRequest: NSURLRequest) {
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
    
    private static func logResponse(urlResponse: NSHTTPURLResponse?, bodyData: NSData?) {
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

extension Request {
    /// Converts a `Request` into an `NSURLRequest` for a given URL.
    ///  Headers and parameters from the `Request` are added to the `NSURLRequest`.
    /// - Parameters:
    ///   - url: The URL to use as the base URL for the request.
    func toNSURLRequestForURL(url: NSURL) -> NSURLRequest? {
        if let urlComponents = NSURLComponents(string: url.absoluteString) {
            var queryItems: [NSURLQueryItem] = []
            for (name, value) in parameters {
                let component = NSURLQueryItem(name: name, value: value)
                queryItems.append(component)
            }
            urlComponents.queryItems = queryItems
            if let url = urlComponents.URL {
                let request = NSMutableURLRequest(URL: url)
                for (name, value) in headers {
                    request.setValue(value, forHTTPHeaderField: name)
                }
                return request
            }
        }
        return nil
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
    /// Attempts to parse this string as JSON and returns the parsed object if successful.
    var jsonObject: AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
}