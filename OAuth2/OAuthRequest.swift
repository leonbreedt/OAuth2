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
import Decodable

protocol OAuth2Request {
    var url: String { get }
    var headers: [String: String] { get }
    var parameters: [String: String] { get }
}

enum OAuth2Response {
    case Success(token: String, refreshToken: String?)
    case Failure(reason: String)
}

struct OAuth2ClientCredentialResponse {
    var tokenType: String
    var accessToken: String
    var expiresIn: Int?
}

struct OAuth2ClientCredentialRequest : OAuth2Request {
    var url: String
    var headers: [String: String]
    var parameters: [String: String]
    
    init(url: String, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        self.url = url
        self.headers = [:]
        self.parameters = [:]
        
        self.parameters["grant_type"] = "client_credentials"
        if !useAuthorizationHeader {
            self.parameters["client_id"] = clientId
            self.parameters["client_secret"] = clientSecret
        } else {
            let credentials = "\(clientId):\(clientSecret)".base64Value!
            self.headers["Authorization"] = "Basic \(credentials)"
        }
    }
}

typealias OAuth2AuthenticationCallback = OAuth2Response -> Void

class OAuth2Authenticator {
    private var session: NSURLSession
    
    init(session: NSURLSession? = nil) {
        self.session = session ?? {
            let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
            return NSURLSession(configuration: configuration)
        }()
    }
    
    func authenticate(request authenticationRequest: OAuth2ClientCredentialRequest,
                      completion: OAuth2AuthenticationCallback? = nil) {
                        
        // TODO: user hook for modifying request before it is sent.
        
        if let request = authenticationRequest.toNSURLRequest() {
            // TODO: log request
            let dataTask = session.dataTaskWithRequest(request) { data, response, error in
                if error != nil {
                    completion?(.Failure(reason: error?.localizedDescription ?? "Unknown error"))
                } else if data != nil {
                    if let stringData = NSString(data: data!, encoding: NSUTF8StringEncoding) as? String,
                       let jsonObject = stringData.jsonObject,
                       let credentialResponse = try? OAuth2ClientCredentialResponse.decode(jsonObject) {
                        // TODO: log response
                        // TODO: user hook for extracting token and refresh token from response
                        // TODO: parse JSON if no user hook
                        
                        print("credential response: \(credentialResponse)")
                        
                        completion?(.Success(token: credentialResponse.accessToken, refreshToken: nil))
                    } else {
                        completion?(.Failure(reason: "Failed to parse response"))
                    }
                }
            }
            dataTask.resume()
        } else {
            completion?(.Failure(reason: "Failed to create request"))
        }
    }
}

extension OAuth2Request {
    func toNSURLRequest() -> NSURLRequest? {
        if let urlComponents = NSURLComponents(string: url) {
            for (name, value) in parameters {
                let component = NSURLQueryItem(name: name, value: value)
                urlComponents.queryItems?.append(component)
            }
            if let url = urlComponents.URL {
                let request = NSURLRequest(URL: url)
                return request
            }
        }
        return nil
    }
}

extension OAuth2ClientCredentialResponse : Decodable {
    static func decode(json: AnyObject) throws -> OAuth2ClientCredentialResponse {
        return try OAuth2ClientCredentialResponse(
            tokenType: json => "token_type",
            accessToken: json => "access_token",
            expiresIn: json => "expires_in")
    }
}

extension String {
    var base64Value: String? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)?
                   .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
    
    var jsonObject: AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
}