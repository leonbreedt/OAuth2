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

import WebKit

/// Handler called when an OAuth authorization request has completed.
public typealias AuthorizationCompletionHandler = Response -> Void

/// Responsible for creating a web view controller.
public typealias CreateWebViewController =
    (NSURLRequest, NSURL, WebViewCompletionHandler) -> WebViewControllerType

/// The entry point into performing OAuth requests in this framework.
public class OAuth2 {
    /// Performs an OAuth `authorization_code` flow, calling the completion handler
    /// when the request is finished.
    /// Will present a modal web view controller through which the user will log in to the target service.
    /// This view controller will be dismissed when the user clicks cancel, authentication succeeds or
    /// authentication fails.
    /// - Parameters:
    ///   - request: The authorization request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about
    ///                 which dispatch queue the completion will be called on.
    ///   - createWebViewController: If not `nil`, a function to call to create a `WebViewControllerType`
    ///                              to perform the user interaction. The default implementation
    ///                              uses `WKWebView` to perform the user interaction. The
    ///                              object returned must be either a `UIViewController` (iOS) or
    ///                              `NSViewController` (OS X). This can also be supplied if
    ///                              the caller wants to customize the presentation of this view
    ///                              controller, via _transitioning delegates_, for example.
    public static func authorize(request: AuthorizationCodeRequest,
                                 createWebViewController: CreateWebViewController? = nil,
                                 completion: AuthorizationCompletionHandler) {
        var createController: CreateWebViewController = createDefaultWebViewController
        if createWebViewController != nil {
            createController = createWebViewController!
        }

        webViewRequestHook(request.authorizationRequest(),
                           redirectionURL: request.redirectURL,
                           createWebViewController: createController) { response in
            switch response {
            case .LoadError(let error):
                completion(.Failure(failure: error))
                break
            case .Redirection(let redirectionURL):
                let queryParameters = redirectionURL.queryParameters
                if let code = queryParameters["code"] {
                    urlRequestHook(request.tokenRequest(code)) { data, urlResponse, error in
                        processAuthorizationDataResponse(data,
                                                         urlResponse: urlResponse,
                                                         error: error,
                                                         completion: completion)
                    }
                } else if let error = queryParameters["error"] {
                    let description = queryParameters["error_description"]?.urlDecodedString
                    let failure = ErrorData(error: error, errorDescription: description, errorURI: nil)
                    completion(.Failure(failure: failure.asAuthorizationFailure()))
                } else {
                    completion(.Failure(failure: AuthorizationFailure.MissingParametersInRedirectionURI))
                }
                break
            case .ResponseError(let response):
                logResponse(response, bodyData: nil)
                let failure = AuthorizationFailure.UnexpectedServerResponse(response: response)
                completion(.Failure(failure: failure))
                break
            }
        }
    }

    /// Performs an OAuth `refresh_token` flow, calling a completion handler when the request
    /// has finished. No user interaction is required for this flow.
    /// - Parameters:
    ///   - request: The refresh token request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about
    ///                 which dispatch queue the completion will be called on.
    public static func refresh(request: RefreshTokenRequest,
                               completion: AuthorizationCompletionHandler) {
        urlRequestHook(request.tokenRequest()) { data, urlResponse, error in
            processAuthorizationDataResponse(data,
                                             urlResponse: urlResponse,
                                             error: error,
                                             completion: completion)
        }
    }

    /// Performs an OAuth `client_credentials` flow, calling a completion handler when the
    /// request has finished. No user interaction is required for this flow.
    /// - Parameters:
    ///   - request: The authorization request to perform.
    ///   - completion: The `AuthorizationCompletionHandler` to call when the request has completed
    ///                 (successfully or not). The caller must not make any assumptions about
    ///                 which dispatch queue the completion will be called on.
    public static func authorize(request: ClientCredentialsRequest,
                                 completion: AuthorizationCompletionHandler) {
        urlRequestHook(request.authorizationRequest()) { data, urlResponse, error in
            processAuthorizationDataResponse(data,
                                             urlResponse: urlResponse,
                                             error: error,
                                             completion: completion)
        }
    }

    /// Whether or not HTTP requests and responses will be logged.
    public static var loggingEnabled: Bool = false

    /// If not `nil`, the `NSURLSessionConfiguration` to use when performing any direct URL
    /// requests. Use this if you need to override details like cache policy, cookie storage, etc.
    /// The default behavior is to use `NSURLSessionConfiguration.ephemeralSessionConfiguration()`,
    /// which does not persist any of this information.
    public static var urlSessionConfiguration: NSURLSessionConfiguration =
        NSURLSessionConfiguration.ephemeralSessionConfiguration()

    /// If not `nil`, the `WKWebViewConfiguration` to use for any new `WKWebView` instances
    /// created after setting this value. Use this if you need to override the process pool
    /// or data store used by the web view, for example. The default behaviour is to use
    /// a new `WKWebViewConfiguration` with a non-persistent data store.
    public static var webViewConfiguration: WKWebViewConfiguration = {
            let configuration = WKWebViewConfiguration()
            configuration.websiteDataStore = WKWebsiteDataStore.nonPersistentDataStore()
            return configuration
        }()

    // MARK: - Internal test hooks

    typealias URLRequestCompletionHandler = (NSData?, NSURLResponse?, ErrorType?) -> Void
    typealias URLRequestHookType = (NSURLRequest, completionHandler: URLRequestCompletionHandler) -> Void
    typealias WebViewRequestHookType =
        (NSURLRequest, redirectionURL: NSURL, createWebViewController: CreateWebViewController,
         completionHandler: WebViewCompletionHandler) -> Void

    static var urlRequestHook: URLRequestHookType = OAuth2.executeURLRequest
    static var webViewRequestHook: WebViewRequestHookType = OAuth2.executeWebViewRequest

    // MARK: - Private

    private init() {
    }

    private static func executeURLRequest(request: NSURLRequest,
                                          completionHandler: URLRequestCompletionHandler) {
        logRequest(request)

        let session = NSURLSession(configuration: urlSessionConfiguration)

        let task = session.dataTaskWithRequest(request) { data, response, error in
            logResponse(response as? NSHTTPURLResponse, bodyData: data)
            completionHandler(data, response, error)
        }
        task.resume()
    }

    private static func executeWebViewRequest(request: NSURLRequest,
                                              redirectionURL: NSURL,
                                              createWebViewController: CreateWebViewController,
                                              completionHandler: WebViewCompletionHandler) {
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

    private static func createDefaultWebViewController(
        request: NSURLRequest,
        redirectionURL: NSURL,
        completionHandler: WebViewCompletionHandler) -> WebViewControllerType {
#if os(iOS)
        let controller = WebViewController(request: request,
                                           redirectionURL: redirectionURL,
                                           completionHandler: completionHandler)
#elseif os(OSX)
        let controller = WebViewController(request: request,
                                           redirectionURL: redirectionURL,
                                           completionHandler: completionHandler)!
#endif

        controller.webViewConfiguration = webViewConfiguration

        return controller
    }

    private static func processAuthorizationDataResponse(data: NSData?,
                                                         urlResponse: NSURLResponse?,
                                                         error: ErrorType?,
                                                         completion: AuthorizationCompletionHandler) {
        if error != nil {
            completion(.Failure(failure: error!))
            return
        }
        guard let response = urlResponse as? NSHTTPURLResponse else {
            fatalError("unsupported response type: \(urlResponse)")
        }
        if response.statusCode != 400 && response.statusCode != 200 {
            let failure = AuthorizationFailure.UnexpectedServerResponse(response: response)
            completion(.Failure(failure: failure))
            return
        }
        let header = (response.allHeaderFields["Content-Type"] as? String) ?? "application/octet-stream"
        let (mimeType, encoding) = header.parseAsHTTPContentTypeHeader()
        guard let data = data, str = NSString(data: data, encoding: encoding) as? String else {
            completion(.Failure(failure: AuthorizationDataInvalid.NotUTF8))
            return
        }

        do {
            let object: AnyObject?
            if mimeType == "application/json" || mimeType == "text/json" || mimeType == "text/x-json" {
                object = try str.parseAsJSONObject()
            } else {
                object = str.parseAsURLEncodedFormData()
            }
            if object == nil {
                completion(.Failure(failure: ErrorDataInvalid.NotUTF8))
                return
            }
            if response.statusCode == 400 {
                completion(decodeErrorData(object!))
            } else {
                completion(decodeAuthorizationData(object!))
            }
        } catch let parseError {
            completion(.Failure(failure: AuthorizationDataInvalid.MalformedJSON(error: parseError)))
        }
    }

    private static func decodeAuthorizationData(object: AnyObject) -> Response {
        do {
            let authData = try AuthorizationData.decode(object)
            return .Success(data: authData)
        } catch let error {
            return .Failure(failure: error)
        }
    }

    private static func decodeErrorData(object: AnyObject) -> Response {
        do {
            let errorData = try ErrorData.decode(object)
            return .Failure(failure: errorData.asAuthorizationFailure())
        } catch let error {
            return .Failure(failure: error)
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
