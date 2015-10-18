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
    /// Will display a modal `WebViewController` for the user to use when logging into the third party service.
    /// This view controller will be dismissed when the user clicks cancel, authentication succeeds, or fails.
    /// - Parameters:
    ///   - request: The authorization request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about which dispatch queue
    ///                 it will be called on.
    public static func authorize(
        request: AuthorizationCodeRequest,
        completion: AuthorizationCompletionHandler)
    {
        // 1. Obtain an authorization code. This requires firing up a web browser, and having the user log in to it.
        executeWebViewRequest(request.authorizationRequest(), redirectionURL: request.redirectURL) { queryParameters, error in
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
                executeURLRequest(request.tokenRequest(code)) { data, urlResponse, error in
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
    /// request has finished. This is a two-legged flow, and no user interaction is required.
    /// - Parameters:
    ///   - request: The request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). May be set to `nil`, in which case the caller will receive
    ///                 no notification of completion.
    ///                 The caller must not make any assumptions about which dispatch queue the completion will be
    ///                 called on.
    ///     - Parameters:
    ///       - response: The `Response` representing the result of the authentication.
    public static func authorize(
        request: ClientCredentialsRequest,
        completion: AuthorizationCompletionHandler)
    {
        executeURLRequest(request.authorizationRequest()) { data, urlResponse, error in
            handleAuthorizationDataResponse(data, urlResponse: urlResponse, error: error, completion: completion)
        }
    }
    
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
            case .Error(let error):
                completionHandler(nil, error)
                break
            case .Redirection(let redirectionURL):
                completionHandler(redirectionURL.queryParameters, nil)
                break
            case .ResponseError(let error, let httpResponse):
                logResponse(httpResponse, bodyData: nil)
                completionHandler(nil, error)
                break
            }
        }
        
#if os(iOS)
        UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(controller, animated: true, completion: nil)
#endif
        
        controller.loadRequest()
    }
    
    private static func handleAuthorizationDataResponse(data: NSData?, urlResponse: NSURLResponse?, error: ErrorType?, completion: AuthorizationCompletionHandler) {
        if error != nil {
            completion(.Failure(failure: error!))
            return
        }

        assert(urlResponse is NSHTTPURLResponse)
        
        let httpResponse = urlResponse as! NSHTTPURLResponse
        if httpResponse.statusCode < 200 || httpResponse.statusCode > 299 {
            completion(.Failure(failure: AuthorizationFailure.InvalidResponseStatusCode))
            return
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
            guard let jsonObject = try utf8String.jsonObject() else {
                completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
                return
            }
            do {
                let authData = try AuthorizationData.decode(jsonObject)
                completion(.Success(data: authData))
            } catch let error {
                completion(.Failure(failure: error))
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

extension AuthorizationData {
    /// Decodes authorization data JSON into an `AuthorizationData` object.
    public static func decode(json: AnyObject) throws -> AuthorizationData {
        guard let dict = json as? NSDictionary else { throw AuthorizationDataInvalid.NotJSONObject }
        guard let accessToken = dict["access_token"] as? String else { throw AuthorizationDataInvalid.MissingAccessToken }
        let refreshToken = dict["refresh_token"] as? String
        let expiresInSeconds = dict["expires_in"] as? Int
        return AuthorizationData(accessToken: accessToken, refreshToken: refreshToken, expiresInSeconds: expiresInSeconds)
    }
}

extension String {
    /// Attempts to parse this string as JSON and returns the parsed object if successful.
    func jsonObject() throws -> AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
    
    var urlDecodedString: String {
        return NSString(string: self).stringByRemovingPercentEncoding?.stringByReplacingOccurrencesOfString("+", withString: " ") ?? self
    }
    
    var queryUrlEncodedString: String? {
        return NSString(string: self).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }
}

extension NSURL {
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
    func toDictionary<K, V>(transform: Element -> (K, V)) -> [K: V] {
        var dict: [K: V] = [:]
        for item in self {
            let (key, value) = transform(item)
            dict[key] = value
        }
        return dict
    }
}