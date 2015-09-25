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

/// Represents a general OAuth 2.0 request.
public protocol Request {
    /// The authorization URL for the request, if applicable to the grant type.
    var authorizationURL: NSURL? { get }
    
    /// The token URL for the request, if applicable to the grant type.
    var tokenURL: NSURL? { get }
    
    /// Any HTTP headers that need to be set for the request.
    var headers: [String: String] { get }
    
    /// Any URI parameters that need to be set for the request.
    var parameters: [String: String] { get }
}

/// Represents an OAuth 2.0 `authorization_code` request. This is a three-legged flow, and
/// requires that a user agent (e.g. web browser) be available to handle the user login.
public struct AuthorizationCodeRequest : Request {
    public let authorizationURL: NSURL?
    public var tokenURL: NSURL? = nil
    public let headers: [String: String]
    public let parameters: [String: String]
    
    /// Initializes a `authorization_code` request.
    /// - Parameters:
    ///   - authorizationURI: The URL of the authorization service.
    ///   - tokenURL: The URL of the service that will provide the tokens once a code has been issued.
    ///   - clientId: The client ID for the caller, must have been configured on the service.
    ///   - scope: The scope to request, application-specific.
    ///   - redirectURL: The URL which the service will redirect to once the user authentication has completed.
    ///                  For native apps (e.g. iOS), you typically want to set this to a URL scheme registered to your
    ///                  application, so that you can close the web browser control, etc.
    ///   - state: An opaque string which will be round-tripped (added as a parameter in redirections) 
    ///            during the authorization.
    /// - Returns: `nil` if either the `authorizationURL` or `tokenURL` parameters are not valid URLs.
    init?(authorizationURL authorizationURLString: String,
        tokenURL tokenURLString: String,
        clientId: String,
        scope: String,
        redirectURL: String,
        state: String? = nil)
    {
        if let authorizationURL = NSURL(string: authorizationURLString),
           let tokenURL = NSURL(string: tokenURLString)
        {
            self.init(
                authorizationURL: authorizationURL,
                tokenURL: tokenURL,
                clientId: clientId,
                scope: scope,
                redirectURL: redirectURL,
                state: state
            )
        } else {
            return nil
        }
    }
    
    /// Initializes a `authorization_code` request.
    /// - Parameters:
    ///   - authorizationURI: The URL of the authorization service.
    ///   - tokenURL: The URL of the service that will provide the tokens once a code has been issued.
    ///   - clientId: The client ID for the caller, must have been configured on the service.
    ///   - scope: The scope to request, application-specific.
    ///   - redirectURL: The URL which the service will redirect to once the user authentication has completed.
    ///                  For native apps (e.g. iOS), you typically want to set this to a URL scheme registered to your
    ///                  application, so that you can close the web browser control, etc.
    ///   - state: An opaque string which will be round-tripped (added as a parameter in redirections)
    ///            during the authorization.
    init(authorizationURL: NSURL,
        tokenURL: NSURL,
        clientId: String,
        scope: String,
        redirectURL: String,
        state: String? = nil)
    {
        var parameters: [String : String] = [:]
        parameters["client_id"] = clientId
        parameters["response_type"] = "code"
        parameters["scope"] = scope
        parameters["redirect_uri"] = redirectURL
        if state != nil {
            parameters["state"] = state!
        }
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.headers = [:]
        self.parameters = parameters
    }
}

/// Represents an OAuth 2.0 `client_credentials` request. This is a two-legged flow.
public struct ClientCredentialsRequest : Request {
    public let authorizationURL: NSURL?
    public let tokenURL: NSURL? = nil
    public let headers: [String: String]
    public let parameters: [String: String]
    
    /// Initializes a `client_credentials` request.
    /// - Parameters:
    ///   - url: The URL of the authorization service.
    ///   - clientId: The client ID for the caller, must have been configured on the service.
    ///   - clientSecret: The client secret for the caller, must have been provided by the service.
    ///   - useAuthorizationHeader: Whether or not to use the `Authorization` HTTP header. If not used,
    ///                             the `client_id` and `client_secret` parameters will be passed via
    ///                             HTTP request parameters instead.
    /// - Returns: `nil` if the `url` parameter is not a valid URL.
    init?(url: String, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        if let authorizationURL = NSURL(string: url) {
            self.init(url: authorizationURL,
                      clientId: clientId,
                      clientSecret: clientSecret,
                      useAuthorizationHeader: useAuthorizationHeader)
        } else {
            return nil
        }
    }
    
    /// Initializes a `client_credentials` request.
    /// - Parameters:
    ///   - url: The URL of the authorization service.
    ///   - clientId: The client ID for the caller, must have been provided by the service.
    ///   - clientSecret: The client secret for the caller, must have been provided by the service.
    ///   - useAuthorizationHeader: Whether or not to use the `Authorization` HTTP header. If not used,
    ///                             the `client_id` and `client_secret` parameters will be passed via
    ///                             HTTP request parameters instead.
    init(url: NSURL, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        var parameters: [String : String] = [:]
        var headers: [String : String] = [:]
        parameters["grant_type"] = "client_credentials"
        if !useAuthorizationHeader {
            parameters["client_id"] = clientId
            parameters["client_secret"] = clientSecret
        } else {
            let credentials = "\(clientId):\(clientSecret)".base64String!
            headers["Authorization"] = "Basic \(credentials)"
        }
        self.authorizationURL = url
        self.parameters = parameters
        self.headers = headers
    }
}

extension String {
    /// A Base64 encoding of the UTF-8 bytes for this string.
    var base64String: String? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)?
                   .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
}