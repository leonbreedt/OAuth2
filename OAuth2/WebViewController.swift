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

#if os(iOS)
import UIKit
#elseif os(OSX)
import Cocoa
#endif
import WebKit

/// Enumerates the possible responses for a web view based request.
public enum WebViewResponse {
    /// A general error occurred while attempting to load the request.
    /// - Parameters:
    ///   - error: The error that occurred while loading.
    case LoadError(error: ErrorType)

    /// An error occurred while attempting to load the request, and the HTTP response is available for further consultation.
    /// - Parameters:
    ///   - response: The HTTP response that can be consulted to attempt to determine the root cause.
    case ResponseError(response: NSHTTPURLResponse)
    
    /// Completed, and a redirect was performed.
    /// - Parameters:
    ///   - redirectionURL: The full URL (with any query parameters) that the server redirected to.
    case Redirection(redirectionURL: NSURL)
}

/// A completion handler for web view requests.
public typealias WebViewCompletionHandler = WebViewResponse -> Void

/// Controller for displaying a web view, performing an `NSURLRequest` inside it, 
/// and intercepting redirects to a well-known URL.
public class WebViewController: UIViewController, WKNavigationDelegate {
    weak var webView: WKWebView!
    
    let request: NSURLRequest!
    let redirectionURL: NSURL!
    let completionHandler: WebViewCompletionHandler!

    /// Creates a new `WebViewController` for an `NSURLRequest` and a given redirection URL.
    /// - Parameters:
    ///   - request: The URL request that will be loaded when `loadRequest` is called.
    ///   - redirectionURL: The redirection URL which will trigger a completion if the server attempts to redirect to it.
    ///   - completionHandler: The handler to call when the request completes (successfully or otherwise).
    public init(request: NSURLRequest, redirectionURL: NSURL, completionHandler: WebViewCompletionHandler) {
        self.request = request
        self.redirectionURL = redirectionURL
        self.completionHandler = completionHandler
        super.init(nibName: nil, bundle: nil)
    }

    /// Not supported for `WebViewController`.
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported for WebViewController")
    }
    
    /// Loads the web view's `NSURLRequest`, invoking `completionHandler` when a redirection attempt
    /// to the `redirectionURL` is made.
    public func loadRequest() {
        webView.loadRequest(request)
    }
    
    // MARK: - UIViewController
    
    public override func loadView() {
        super.loadView()
        let webView = WKWebView(frame: CGRectZero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        view.addSubview(webView)
        self.webView = webView
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        webView.frame = view.bounds
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
        if let targetURL = navigationAction.request.URL {
            if targetURL.absoluteString.lowercaseString.hasPrefix(redirectionURL.absoluteString.lowercaseString) {
                completionHandler(.Redirection(redirectionURL: targetURL))
                decisionHandler(.Cancel)
                return
            }
        }
        decisionHandler(.Allow)
    }
    
    public func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
        if let httpResponse = navigationResponse.response as? NSHTTPURLResponse {
            if httpResponse.statusCode >= 400 || httpResponse.statusCode < 200 {
                // Probably, something is bad with the request, server did not like it.
                // Forward the details on so someone else can do something meaningful with it.
                completionHandler(.ResponseError(response: httpResponse))
                decisionHandler(.Cancel)
                return
            }
        }
        decisionHandler(.Allow)
    }
    
    public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        completionHandler(.LoadError(error: error))
    }
}