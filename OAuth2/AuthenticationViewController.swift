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

import UIKit
import WebKit

class AuthenticationViewController: UIViewController, WKNavigationDelegate {
    var webView: WKWebView!
    var navigation: WKNavigation!
    
    override func loadView() {
        super.loadView()
        
        let webViewConfiguration = WKWebViewConfiguration()
        webView = WKWebView(frame: view.bounds, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        
        view.addSubview(webView)
    }
    
    func authenticateWithRequest(request: NSURLRequest) {
        navigation = webView.loadRequest(request)
    }
    
    // MARK: - WKNavigationDelegate
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        if navigation == self.navigation {
            
        }
    }
}
