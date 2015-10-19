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

/// Represents an OAuth 2.0 `authorization_code` request. This is a three-legged flow, and
/// requires that a user agent (e.g. web browser) be available to handle the user login.
public struct AuthorizationCodeRequest {
    /// The URL of the authorization endpoint.
    public let authorizationURL: NSURL
    /// The URL of the token issuing endpoint.
    public let tokenURL: NSURL
    /// The client ID for your application, provided by the target service.
    public let clientId: String
    /// The client secret for your application, provided by the target service.
    public let clientSecret: String
    /// The redirect URL configured for your application on the target service. This does not have
    /// to be a live Internet URL, this library will intercept the redirect and process it to
    /// complete the authorization.
    public let redirectURL: NSURL
    /// The scope of permissions to request. May be omitted, depending on the service.
    public let scope: String?
    /// An opaque string which will be round-tripped (added as a parameter in redirections)
    /// during the authorization flow.
    public let state: String?
    
    /// Initializes a `authorization_code` request.
    /// - Parameters:
    ///   - authorizationURL: The URL of the authorization endpoint.
    ///   - tokenURL: The URL of the token issuing endpoint.
    ///   - clientId: The client ID for your application, provided by the target service.
    ///   - clientSecret: The client secret for your application, provided by the target service.
    ///   - redirectURL: The redirect URL configured for your application on the target service. This does not have
    ///                  to be a live Internet URL, this library will intercept the redirect and process it to
    ///                  complete the authorization.
    ///   - scope: The scope of permissions to request. May be omitted, depending on the service.
    ///   - state: An opaque string which will be round-tripped (added as a parameter in redirections)
    ///            during the authorization.
    /// - Returns: `nil` if either the `authorizationURL` or `tokenURL` parameters are not valid URLs.
    public init?(authorizationURL authorizationURLString: String,
        tokenURL tokenURLString: String,
        clientId: String,
        clientSecret: String,
        redirectURL: String,
        scope: String? = nil,
        state: String? = nil)
    {
        if let authorizationURL = NSURL(string: authorizationURLString),
           let tokenURL = NSURL(string: tokenURLString),
           let redirectURL = NSURL(string: redirectURL)
        {
            self.init(
                authorizationURL: authorizationURL,
                tokenURL: tokenURL,
                clientId: clientId,
                clientSecret: clientSecret,
                redirectURL: redirectURL,
                scope: scope,
                state: state
            )
        } else {
            return nil
        }
    }
    
    /// Initializes a `authorization_code` request.
    /// - Parameters:
    ///   - authorizationURL: The URL of the authorization endpoint.
    ///   - tokenURL: The URL of the token issuing endpoint.
    ///   - clientId: The client ID for your application, provided by the target service.
    ///   - clientSecret: The client secret for your application, provided by the target service.
    ///   - redirectURL: The redirect URL configured for your application on the target service. This does not have
    ///                  to be a live Internet URL, this library will intercept the redirect and process it to
    ///                  complete the authorization.
    ///   - scope: The scope of permissions to request. May be omitted, depending on the service.
    ///   - state: An opaque string which will be round-tripped (added as a parameter in redirections)
    ///            during the authorization.
    public init(authorizationURL: NSURL,
        tokenURL: NSURL,
        clientId: String,
        clientSecret: String,
        redirectURL: NSURL,
        scope: String? = nil,
        state: String? = nil)
    {
        self.authorizationURL = authorizationURL
        self.tokenURL = tokenURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.scope = scope
        self.redirectURL = redirectURL
        self.state = state
    }
    
    /// Creates a `NSURLRequest` that can be used to obtain an authentication code, which can be
    /// exchanged for an access token.
    func authorizationRequest() -> NSURLRequest {
        var parameters = [
            "client_id" : clientId,
            "response_type" : "code",
            "redirect_uri" : redirectURL.absoluteString
        ]
        if scope != nil {
            parameters["scope"] = scope!
        }
        if state !=  nil {
            parameters["state"] = state!
        }
        return buildURLRequest(authorizationURL, queryParameters: parameters)!
    }
    
    /// Creates a `NSURLRequest` that can be used to obtain an access token for an issued authentication code.
    func tokenRequest(code: String) -> NSURLRequest {
        var parameters = [
            "client_id" : clientId,
            "client_secret" : clientSecret,
            "code" : code,
            "redirect_uri" : redirectURL.absoluteString,
            "grant_type" : "authorization_code"
        ]
        if state !=  nil {
            parameters["state"] = state!
        }
        return buildURLRequest(tokenURL, formParameters: parameters, method: "POST")!
    }
}

/// Represents an OAuth 2.0 `client_credentials` request. This is a two-legged flow.
public struct ClientCredentialsRequest {
    /// The URL of the authorization endpoint.
    public let authorizationURL: NSURL
    /// The client ID for your application, provided by the target service.
    public let clientId: String
    /// The client secret for your application, provided by the target service.
    public let clientSecret: String
    /// Whether or not to use the `Authorization` HTTP header for transmitting the
    /// client ID and secret to the server. If `false`, they will be transmitted to
    /// the server using `client_id` and `client_secret` HTTP GET parameters instead,
    /// as per the RFC.
    public let useAuthorizationHeader: Bool
    
    /// Initializes a `client_credentials` request.
    /// - Parameters:
    ///   - url: The URL of the authorization endpoint.
    ///   - clientId: The client ID for your application, provided by the target service.
    ///   - clientSecret: The client secret for your application, provided by the target service.
    ///   - useAuthorizationHeader: Whether or not to use the `Authorization` HTTP header for transmitting the
    ///                             client ID and secret to the server. If `false`, they will be transmitted to
    ///                             the server using `client_id` and `client_secret` HTTP GET parameters instead,
    ///                             as per the RFC.
    /// - Returns: `nil` if the `url` parameter is not a valid URL.
    public init?(authorizationURL: String, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        if let authorizationURL = NSURL(string: authorizationURL) {
            self.init(authorizationURL: authorizationURL,
                      clientId: clientId,
                      clientSecret: clientSecret,
                      useAuthorizationHeader: useAuthorizationHeader)
        } else {
            return nil
        }
    }
    
    /// Initializes a `client_credentials` request.
    /// - Parameters:
    ///   - url: The URL of the authorization endpoint.
    ///   - clientId: The client ID for your application, provided by the target service.
    ///   - clientSecret: The client secret for your application, provided by the target service.
    ///   - useAuthorizationHeader: Whether or not to use the `Authorization` HTTP header for transmitting the
    ///                             client ID and secret to the server. If `false`, they will be transmitted to
    ///                             the server using `client_id` and `client_secret` HTTP GET parameters instead,
    ///                             as per the RFC.
    public init(authorizationURL: NSURL, clientId: String, clientSecret: String, useAuthorizationHeader: Bool = true) {
        self.authorizationURL = authorizationURL
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.useAuthorizationHeader = useAuthorizationHeader
    }
    
    /// Creates a `NSURLRequest` that can be used to obtain an access token.
    func authorizationRequest() -> NSURLRequest {
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
        return buildURLRequest(authorizationURL, queryParameters: parameters, headers: headers)!
    }
}

extension String {
    /// A Base64 encoding of the UTF-8 bytes for this string.
    var base64String: String? {
        return self.dataUsingEncoding(NSUTF8StringEncoding)?
                   .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
    }
}

private func buildURLRequest(url: NSURL,
                             queryParameters: [String: String] = [:],
                             formParameters: [String: String] = [:],
                             headers: [String: String] = [:],
                             method: String = "GET") -> NSMutableURLRequest?
{
    if let urlComponents = NSURLComponents(string: url.absoluteString) {
        var queryItems: [NSURLQueryItem] = []
        for (name, value) in queryParameters {
            guard let encodedValue = value.queryUrlEncodedString else { continue }
            let component = NSURLQueryItem(name: name, value: encodedValue)
            queryItems.append(component)
        }
        urlComponents.queryItems = queryItems
        if let url = urlComponents.URL {
            let request = NSMutableURLRequest(URL: url)
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
            if formParameters.count > 0 {
                var encodedParameters: [String] = []
                for (name, value) in formParameters {
                    guard let encodedValue = value.queryUrlEncodedString else { continue }
                    encodedParameters.append("\(name)=\(encodedValue)")
                }
                let formBody = encodedParameters.joinWithSeparator("&")
                request.HTTPBody = formBody.dataUsingEncoding(NSUTF8StringEncoding)
            }
            request.HTTPMethod = method
            return request
        }
    }
    return nil
}