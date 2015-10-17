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

/// Controller for displaying a web view and capturing the responses of loading a request.
public class WebViewController: UIViewController, WKNavigationDelegate {
    /// The response to the most recent `loadRequest(_:completion:)` call. If the call failed, will be `nil`.
    public var response: NSURLResponse? = nil
    /// If the most recent `loadRequest(_:completion:)` call failed, will contain the error describing the reason for failure.
    public var error: NSError? = nil
    
    private weak var webView: WKWebView!
    private var activeURL: NSURL? = nil
    private var activeNavigation: WKNavigation? = nil
    private var completion: URLResponseHandler? = nil
    
    public override func loadView() {
        super.loadView()
        webView = WKWebView(frame: CGRectZero, configuration: WKWebViewConfiguration())
        view.addSubview(webView)
    }
    
    public override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        webView.frame = view.bounds
    }
    
    /// Loads a `NSURLRequest`, invoking a callback when loading has finished.
    public func loadRequest(request: NSURLRequest, completion: URLResponseHandler ) {
        webView.loadRequest(request)
        self.completion = completion
    }
    
    // MARK: - WKNavigationDelegate
    
    public func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.response.URL == activeURL {
            print("response is \(navigationResponse.response)")
            response = navigationResponse.response
        }
        decisionHandler(.Allow)
    }
    
    public func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        activeURL = webView.URL
        print("redirected to \(activeURL)")
    }
    
  public func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        if activeNavigation != nil && navigation == activeNavigation {
            print("expected navigation finished! \(webView.URL)")
        } else {
            print("unknown navigation finished! \(webView.URL)")
        }
        activeNavigation = nil
        activeURL = nil
        completion?(response, error, nil)
    }
    
    public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        if activeNavigation != nil && navigation == activeNavigation {
            print("navigation failed! \(error)")
        } else {
            print("unknown navigation failed! \(error)")
        }
        activeNavigation = nil
        activeURL = nil
        self.error = error
        completion?(response, error, nil)
    }
}
