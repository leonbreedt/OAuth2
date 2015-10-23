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

var titleObservation = 1

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

/// Represents a view controller that can be used to execute URL requests.
public protocol WebViewControllerType {
    /// Presents the controller and triggers the URL request.
    func present()
    /// Dismisses the controller.
    func dismiss()
}

/// Controller for displaying a web view, performing an `NSURLRequest` inside it, 
/// and intercepting redirects to a well-known URL.
public class WebViewController: UIViewController, WKNavigationDelegate, WebViewControllerType {
    public typealias Element = WebViewController
    weak var webView: WKWebView!
    
    let request: NSURLRequest!
    let redirectionURL: NSURL!
    let completionHandler: WebViewCompletionHandler!

    /// Creates a new `WebViewController` for an `NSURLRequest` and a given redirection URL.
    /// - Parameters:
    ///   - request: The URL request that will be loaded when `loadRequest` is called.
    ///   - redirectionURL: The redirection URL which will trigger a completion if the server attempts to redirect to it.
    ///   - completionHandler: The handler to call when the request completes (successfully or otherwise).
    public required init(request: NSURLRequest, redirectionURL: NSURL, completionHandler: WebViewCompletionHandler) {
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
    public func present() {
        #if os(iOS)
        let navigationController = UINavigationController(rootViewController: self)
        UIApplication.sharedApplication().keyWindow!.rootViewController!.presentViewController(navigationController, animated: true, completion: nil)
        #elseif os(OSX)
        // TODO: Implement
        #endif
        
        loadViewIfNeeded()
        webView.loadRequest(request)
    }
    
    /// Dismisses the view controller.
    public func dismiss() {
        #if os(iOS)
        dismissViewControllerAnimated(true, completion: nil)
        #elseif os(OSX)
            // TODO: Implement
        #endif
    }
    
    // MARK: - UIViewController
    
    public override func loadView() {
        super.loadView()

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: "dismissAndCancel")
        
        let webView = WKWebView(frame: CGRectZero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.addObserver(self, forKeyPath: "title", options: .New, context: &titleObservation)
        view.addSubview(webView)
        let heightConstraint = NSLayoutConstraint(item: webView, attribute: .Height, relatedBy: .Equal, toItem: view, attribute: .Height, multiplier: 1, constant: 0)
        let widthConstraint = NSLayoutConstraint(item: webView, attribute: .Width, relatedBy: .Equal, toItem: view, attribute: .Width, multiplier: 1, constant: 0)
        view.addConstraints([heightConstraint, widthConstraint])
        self.webView = webView
    }
    
    deinit {
        if let webView = webView {
            webView.removeObserver(self, forKeyPath: "title")
        }
    }
    
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if context == &titleObservation {
            if let newTitle = change?[NSKeyValueChangeNewKey] as? String {
                title = newTitle
            }
        }
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
            if httpResponse.statusCode != 200 {
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
    
    // MARK: - Actions
    
    public func dismissAndCancel() {
        dismiss()
        completionHandler(.LoadError(error: AuthorizationFailure.OAuthAccessDenied(description: "User canceled authentication")))
    }
}