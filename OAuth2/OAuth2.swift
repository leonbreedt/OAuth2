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

#if os(iOS)
import UIKit
#endif

/// Handler called when an OAuth authorization request has completed.
public typealias AuthorizationCompletionHandler = Response -> Void

/// The entry point into performing OAuth requests in this framework.
public class OAuth2 {
    /// Performs an OAuth `authorization_code` flow, calling the completion handler when the request is finished.
    /// Will present a modal web view controller through which the user will log in to the target service.
    /// This view controller will be dismissed when the user clicks cancel, authentication succeeds or authentication fails.
    /// - Parameters:
    ///   - request: The authorization request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about
    ///                 which dispatch queue the completion will be called on.
    public static func authorize(
        request: AuthorizationCodeRequest,
        completion: AuthorizationCompletionHandler)
    {
        // 1. Obtain an authorization code. This requires firing up a web browser, and having the user log in to it.
        webViewRequestHook(request.authorizationRequest(), redirectionURL: request.redirectURL) { queryParameters, error in
            if error != nil {
                completion(.Failure(failure: error!))
                return
            }
            
            guard let queryParameters = queryParameters else {
                completion(.Failure(failure: AuthorizationFailure.MissingParametersInRedirectionURI))
                return
            }
            
            if let code = queryParameters["code"] {
                // 2. Issue a token by requesting one from token URL, passing in the received code.
                urlRequestHook(request.tokenRequest(code)) { data, urlResponse, error in
                    handleAuthorizationDataResponse(data, urlResponse: urlResponse, error: error, completion: completion)
                }
            } else if let error = queryParameters["error"] {
                let failure = failureForOAuthError(error, description: queryParameters["error_description"]?.urlDecodedString)
                completion(.Failure(failure: failure))
            } else {
                completion(.Failure(failure: AuthorizationFailure.MissingParametersInRedirectionURI))
            }
        }
    }
    
    /// Performs an OAuth `client_credentials` flow, calling a completion handler when the
    /// request has finished. No user interaction is required for this flow.
    /// - Parameters:
    ///   - request: The authorization request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about 
    ///                 which dispatch queue the completion will be called on.
    public static func authorize(
        request: ClientCredentialsRequest,
        completion: AuthorizationCompletionHandler)
    {
        urlRequestHook(request.authorizationRequest()) { data, urlResponse, error in
            handleAuthorizationDataResponse(data, urlResponse: urlResponse, error: error, completion: completion)
        }
    }
    
    /// Whether or not HTTP requests and responses will be logged.
    public static var loggingEnabled: Bool = false
    
    // MARK: - Test hooks
    
    typealias URLRequestCompletionHandler = (NSData?, NSURLResponse?, ErrorType?) -> Void
    typealias URLRequestHookType = (NSURLRequest, completionHandler: URLRequestCompletionHandler) -> Void
    typealias WebViewRequestCompletionHandler = ([String: String]?, ErrorType?) -> Void
    typealias WebViewRequestHookType = (NSURLRequest, redirectionURL: NSURL, completionHandler: WebViewRequestCompletionHandler) -> Void
    
    static var urlRequestHook: URLRequestHookType = OAuth2.executeURLRequest
    static var webViewRequestHook: WebViewRequestHookType = OAuth2.executeWebViewRequest
    
    // MARK: - Private
    
    private init() {
    }
    
    private static func executeURLRequest(request: NSURLRequest, completionHandler: (NSData?, NSURLResponse?, ErrorType?) -> Void) {
        logRequest(request)
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration)
        
        let task = session.dataTaskWithRequest(request) { data, response, error in
            logResponse(response as? NSHTTPURLResponse, bodyData: data)
            
            completionHandler(data, response, error)
        }
        task.resume()
    }
    
    private static func executeWebViewRequest(request: NSURLRequest, redirectionURL: NSURL, completionHandler: ([String: String]?, ErrorType?) -> Void) {
        logRequest(request)

        var controller: WebViewController! = nil
        
        controller = WebViewController(request: request, redirectionURL: redirectionURL) { response in
            controller.dismissViewControllerAnimated(true, completion: nil)
            controller = nil
            
            switch response {
            case .LoadError(let error):
                completionHandler(nil, error)
                break
            case .Redirection(let redirectionURL):
                completionHandler(redirectionURL.queryParameters, nil)
                break
            case .ResponseError(let httpResponse):
                logResponse(httpResponse, bodyData: nil)
                completionHandler(nil, AuthorizationFailure.UnexpectedServerResponse(response: httpResponse))
                break
            }
        }
        
#if os(iOS)
        UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(controller, animated: true, completion: nil)
#elseif os(OSX)
    
#endif
        
        controller.loadRequest()
    }
    
    private static func handleAuthorizationDataResponse(data: NSData?, urlResponse: NSURLResponse?, error: ErrorType?, completion: AuthorizationCompletionHandler) {
        if error != nil {
            completion(.Failure(failure: error!))
            return
        }

        assert(urlResponse is NSHTTPURLResponse)
        
        
        var responseIsServerRejectionError = false
        
        let httpResponse = urlResponse as! NSHTTPURLResponse
        switch httpResponse.statusCode {
        case 200:
            // Either this is a `client_credentials` response containing the JSON, or this is a `authorization_code` response
            // containing the JSON. Ok to proceed.
            break
        case 400:
            // This is a `client_credentials` response (`authorization_code` would have communicated the error via a redirect).
            // Bail out.
            responseIsServerRejectionError = true
            break
        default:
            // Unexpected server response, bail out and supply response to caller for further diagnostics.
            completion(.Failure(failure: AuthorizationFailure.UnexpectedServerResponse(response: httpResponse)))
            return
        }
        
        var contentIsJson = true
        let contentType = httpResponse.allHeaderFields["Content-Type"] as? String
        switch contentType {
        case .Some("text/json"), .Some("application/json"):
            break
        default:
            contentIsJson = false
        }
        
        guard let data = data else {
            completion(.Failure(failure: AuthorizationDataInvalid.Empty))
            return
        }
        
        guard let utf8String = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
            completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
            return
        }
        
        do {
            if responseIsServerRejectionError {
                var object: AnyObject?
                if contentIsJson {
                    object = try utf8String.parseIntoJSONObject()
                    if object == nil {
                        completion(.Failure(failure: ErrorDataInvalid.NotUTF8))
                        return
                    }
                } else {
                    // Backends like Facebook may give us non-RFC-complaint form data response as plain text. Accomodate this.
                    object = utf8String.parseFormDataIntoDictionary()
                    if object == nil {
                        completion(.Failure(failure: ErrorDataInvalid.NotUTF8))
                        return
                    }
                }
                
                do {
                    let errorData = try ErrorData.decode(object!)
                    completion(.Failure(failure: failureForOAuthError(errorData.error, description: errorData.errorDescription)))
                } catch let error {
                    completion(.Failure(failure: error))
                }
            } else {
                var object: AnyObject?
                if contentIsJson {
                    object = try utf8String.parseIntoJSONObject()
                    if object == nil {
                        completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
                        return
                    }
                } else {
                    // Backends like Facebook may give us non-RFC-complaint form data response as plain text. Accomodate this.
                    object = utf8String.parseFormDataIntoDictionary()
                    if object == nil {
                        completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
                        return
                    }
                }
                
                do {
                    let authData = try AuthorizationData.decode(object!)
                    completion(.Success(data: authData))
                } catch let error {
                    completion(.Failure(failure: error))
                }
            }
        }
        catch let parseError {
            completion(.Failure(failure: AuthorizationDataInvalid.MalformedJSON(error: parseError)))
        }
    }
    
    private static func failureForOAuthError(error: String, description: String?) -> AuthorizationFailure {
        switch error {
        case "invalid_request":
            return AuthorizationFailure.OAuthInvalidRequest(description: description)
        case "unauthorized_client":
            return AuthorizationFailure.OAuthUnauthorizedClient(description: description)
        case "access_denied":
            return AuthorizationFailure.OAuthAccessDenied(description: description)
        case "unsupported_response_type":
            return AuthorizationFailure.OAuthUnsupportedResponseType(description: description)
        case "invalid_scope":
            return AuthorizationFailure.OAuthInvalidScope(description: description)
        case "server_error":
            return AuthorizationFailure.OAuthServerError(description: description)
        case "temporarily_unavailable":
            return AuthorizationFailure.OAuthTemporarilyUnavailable(description: description)
        default:
            return AuthorizationFailure.OAuthUnknownError(description: "Unknown error: \(description) (\(error))")
        }
    }
    
    private static func logRequest(urlRequest: NSURLRequest) {
        if !loggingEnabled { return }
        
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
        if !loggingEnabled { return }

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

extension String {
    /// Attempts to parse this string as JSON and returns the parsed object if successful.
    func parseIntoJSONObject() throws -> AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
    
    /// Parses form data into a dictionary.
    func parseFormDataIntoDictionary() -> AnyObject {
        var dict: [String: String] = [:]
        for field in componentsSeparatedByString("&") {
            let kvp = field.componentsSeparatedByString("=")
            if kvp.count != 2 { continue }
            dict[kvp[0]] = kvp[1].urlDecodedString
        }
        return dict
    }
    
    /// Decodes a URL encoded string, as well as replacing any occurrences of `+` with a space. Returns the original string
    /// if any error occurs while decoding.
    var urlDecodedString: String {
        return NSString(string: self).stringByRemovingPercentEncoding?.stringByReplacingOccurrencesOfString("+", withString: " ") ?? self
    }
    
    /// Encodes a string into a format suitable for using in URL query parameter values, or form POST parameter values.
    var queryUrlEncodedString: String? {
        return NSString(string: self).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }
}

extension NSURL {
    /// Returns a dictionary of the query parameters of this URL.
    var queryParameters : [String: String] {
        let components = NSURLComponents(string: absoluteString)
        let parameterDict = components?
            .queryItems?
            .filter {$0.value != nil}
            .map { ($0.name, $0.value!) }
            .toDictionary { ($0.0, $0.1) } ?? Dictionary<String, String>()
        return parameterDict
    }
}

extension Array {
    /// Converts this array to a dictionary of type `[K: V]`.
    /// - Parameters:
    ///   - transform: A function to transform an array element of type `Element` into a `(K, V)` tuple.
    func toDictionary<K, V>(transform: Element -> (K, V)) -> [K: V] {
        var dict: [K: V] = [:]
        for item in self {
            let (key, value) = transform(item)
            dict[key] = value
        }
        return dict
    }
}