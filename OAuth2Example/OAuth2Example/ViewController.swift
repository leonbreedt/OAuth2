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
import OAuth2

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        OAuth2.loggingEnabled = true
    }
    
    // MARK: - Actions
    
    @IBAction
    func authenticateWithGoogle()
    {
        print("authenticating with Google")
    }

    @IBAction
    func authenticateWithFacebook()
    {
        print("authenticating with Facebook")
        // You need to set up the redirect URL in your app settings before it will work.
        let request = AuthorizationCodeRequest(
            authorizationURL: "https://graph.facebook.com/oauth/authorize",
            tokenURL: "https://graph.facebook.com/oauth/access_token",
            clientId: "YOUR-APP-ID-HERE",
            clientSecret: "YOUR-APP-SECRET-HERE",
            redirectURL: "YOUR-REDIRECT-URI-HERE")!
        OAuth2.authorize(request, completion: printOAuthResponse)
    }
    
    @IBAction
    func authenticateWithSoundCloud()
    {
        print("authenticating with SoundCloud")
        let request = AuthorizationCodeRequest(
            authorizationURL: "https://soundcloud.com/connect",
            tokenURL: "https://api.soundcloud.com/oauth2/token",
            clientId: "YOUR-ID-HERE",
            clientSecret: "YOUR-SECRET-HERE",
            redirectURL: "http://localhost/oauth")!
        OAuth2.authorize(request, completion: printOAuthResponse)
    }
    
    func printOAuthResponse(response: Response) {
        switch response {
        case .Success(let data):
            print("authorization completed, access token is \(data.accessToken), expires in \(data.expiresInSeconds), refresh token is '\(data.refreshToken)'")
            break
        default:
            print("authorization failed with response \(response)")
        }
    }
}

