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
    }
    
    // MARK: - Actions
    
    @IBAction
    func authenticateWithGoogle()
    {
        print("authenticating with Google")
    }

    @IBAction
    func authenticateWithTwitter()
    {
        print("authenticating with Twitter")
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
            redirectURL: "YOUR-URL-HERE")!
        OAuth2.authorize(request) { response in
            switch response {
            case .Success(let data):
                print("authorization completed, access token is \(data.accessToken), expires in \(data.expiresInSeconds), refresh token is '\(data.refreshToken)'")
                break
            default:
                print("authorization failed with response \(response)")
            }
        }
    }
}

