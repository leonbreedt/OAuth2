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

/// Handler called when an OAuth authorization request has completed.
public typealias AuthorizationCompletionHandler = Response -> Void

/// Responsible for creating a web view controller.
public typealias CreateWebViewController = (NSURLRequest, NSURL, WebViewCompletionHandler) -> WebViewControllerType

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
    ///   - createWebViewController: If not `nil`, a function to call to create a `WebViewControllerType` to perform
    ///                              the user interaction. The default implementation uses `WKWebView` to perform the user
    ///                              interaction. The object returned must be either a `UIViewController` (iOS) or 
    ///                              `NSViewController` (OS X). This can also be supplied if the caller wants to customize
    ///                              the presentation of this view controller, via _transitioning delegates_, for example.
    public static func authorize(
        request: AuthorizationCodeRequest,
        createWebViewController: CreateWebViewController? = nil,
        completion: AuthorizationCompletionHandler)
    {
        var createController: CreateWebViewController = createDefaultWebViewController
        if createWebViewController != nil {
            createController = createWebViewController!
        }
        
        webViewRequestHook(request.authorizationRequest(), redirectionURL: request.redirectURL, createWebViewController: createController) { response in
            switch response {
            case .LoadError(let error):
                completion(.Failure(failure: error))
                break
            case .Redirection(let redirectionURL):
                let queryParameters = redirectionURL.queryParameters
                if let code = queryParameters["code"] {
                    urlRequestHook(request.tokenRequest(code)) { data, urlResponse, error in
                        processAuthorizationDataResponse(data, urlResponse: urlResponse, error: error, completion: completion)
                    }
                } else if let error = queryParameters["error"] {
                    let failure = ErrorData(error: error, errorDescription: queryParameters["error_description"]?.urlDecodedString, errorURI: nil)
                    completion(.Failure(failure: failure.asAuthorizationFailure()))
                } else {
                    completion(.Failure(failure: AuthorizationFailure.MissingParametersInRedirectionURI))
                }
                break
            case .ResponseError(let httpResponse):
                logResponse(httpResponse, bodyData: nil)
                completion(.Failure(failure: AuthorizationFailure.UnexpectedServerResponse(response: httpResponse)))
                break
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
            processAuthorizationDataResponse(data, urlResponse: urlResponse, error: error, completion: completion)
        }
    }
    
    /// Whether or not HTTP requests and responses will be logged.
    public static var loggingEnabled: Bool = false
    
    // MARK: - Internal test hooks
    
    typealias URLRequestCompletionHandler = (NSData?, NSURLResponse?, ErrorType?) -> Void
    typealias URLRequestHookType = (NSURLRequest, completionHandler: URLRequestCompletionHandler) -> Void
    typealias WebViewRequestHookType = (NSURLRequest, redirectionURL: NSURL, createWebViewController: CreateWebViewController, completionHandler: WebViewCompletionHandler) -> Void
    
    static var urlRequestHook: URLRequestHookType = OAuth2.executeURLRequest
    static var webViewRequestHook: WebViewRequestHookType = OAuth2.executeWebViewRequest
    
    // MARK: - Private
    
    private init() {
    }
    
    private static func executeURLRequest(request: NSURLRequest, completionHandler: URLRequestCompletionHandler) {
        logRequest(request)
        
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: configuration)
        
        let task = session.dataTaskWithRequest(request) { data, response, error in
            logResponse(response as? NSHTTPURLResponse, bodyData: data)
            
            completionHandler(data, response, error)
        }
        task.resume()
    }
    
    private static func executeWebViewRequest(request: NSURLRequest, redirectionURL: NSURL, createWebViewController: CreateWebViewController, completionHandler: WebViewCompletionHandler) {
        dispatch_async(dispatch_get_main_queue()) {
            logRequest(request)
            
            var controller: WebViewControllerType!
            
            controller = createWebViewController(request, redirectionURL) { response in
                controller.dismiss()
                completionHandler(response)
                controller = nil
            }
            
            controller.present()
        }
    }

    private static func createDefaultWebViewController(request: NSURLRequest, redirectionURL: NSURL, completionHandler: WebViewCompletionHandler) -> WebViewControllerType {
#if os(iOS)
        return WebViewController(request: request, redirectionURL: redirectionURL, completionHandler: completionHandler)
#elseif os(OSX)
        return WebViewController(request: request, redirectionURL: redirectionURL, completionHandler: completionHandler)!
#endif
    }
    
    private static func processAuthorizationDataResponse(data: NSData?, urlResponse: NSURLResponse?, error: ErrorType?, completion: AuthorizationCompletionHandler) {
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
        
        guard let data = data else {
            completion(.Failure(failure: AuthorizationDataInvalid.Empty))
            return
        }
        
        guard let utf8String = NSString(data: data, encoding: NSUTF8StringEncoding) as? String else {
            completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
            return
        }

        var contentType: String = "application/octet-stream"
        if let contentTypeHeader = httpResponse.allHeaderFields["Content-Type"] as? String {
            let (type, _) = contentTypeHeader.parseAsHTTPContentTypeHeader()
            contentType = type
        }

        do {
            var object: AnyObject?
            if contentType == "application/json" || contentType == "text/json" || contentType == "text/x-json" {
                object = try utf8String.parseAsJSONObject()
            } else {
                // Backends like Facebook may give us non-RFC-complaint form data response as plain text. Accomodate this.
                object = utf8String.parseAsURLEncodedFormData()
            }
            
            if responseIsServerRejectionError {
                if object == nil {
                    completion(.Failure(failure: ErrorDataInvalid.NotUTF8))
                    return
                }
                do {
                    let errorData = try ErrorData.decode(object!)
                    completion(.Failure(failure: errorData.asAuthorizationFailure()))
                } catch let error {
                    completion(.Failure(failure: error))
                }
            } else {
                if object == nil {
                    completion(.Failure(failure: ErrorDataInvalid.NotUTF8))
                    return
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
    
    private static func logRequest(urlRequest: NSURLRequest) {
        if !loggingEnabled { return }
        print(urlRequest.dumpHeadersAndBody())
    }
    
    private static func logResponse(urlResponse: NSHTTPURLResponse?, bodyData: NSData?) {
        if !loggingEnabled { return }
        print(urlResponse?.dumpHeadersAndBody(bodyData))
    }
}