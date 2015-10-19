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

/// Represents the response to an authorization attempt.
public enum Response {
    /// A successful authorization.
    /// - Parameters:
    ///   - data: An `AuthorizationData` containing access tokens and other information returned by the server.
    case Success(data: AuthorizationData)
    
    /// A failed authorization.
    /// - Parameters:
    ///   - failure: An `ErrorType` containing more details about the cause of the failure.
    case Failure(failure: ErrorType)
}

/// Contains data returned by the server for a successful authorization.
public struct AuthorizationData {
    /// The token that can be used to access the protected resources.
    public let accessToken: String
    
    /// The refresh token that can be used to obtain a replacement token when the access token expires.
    public let refreshToken: String?
    
    /// The amount of time, in seconds, until the access token expires, from the time that the token was issued.
    public let expiresInSeconds: Int?
    
    /// Decodes a JSON object into an `AuthorizationData` model object
    /// - Parameters:
    ///   - json: An object that was parsed from JSON.
    public static func decode(json: AnyObject) throws -> AuthorizationData
    {
        guard let dict = json as? NSDictionary else { throw AuthorizationDataInvalid.NotJSONObject }
        guard let accessToken = dict["access_token"] as? String else { throw AuthorizationDataInvalid.MissingAccessTokenField }
        let refreshToken = dict["refresh_token"] as? String
        var expiresInSeconds = (dict["expires_in"] as? Int)
        
        // Some backends put it as a String in "expires" field. What is an RFC?
        if expiresInSeconds == nil {
            let expires = dict["expires"] as? String
            if expires != nil {
                expiresInSeconds = Int(expires!)
            }
        }
        
        return AuthorizationData(accessToken: accessToken, refreshToken: refreshToken, expiresInSeconds: expiresInSeconds)
    }
}

/// Enumerates the types of failures that can be encountered when attempting to parse authorization data JSON.
public enum AuthorizationDataInvalid : ErrorType {
    /// The data is not available or empty.
    case Empty
    
    /// The data is not valid UTF-8.
    case NotUTF8
    
    /// The data is not JSON, or is malformed with syntax errors.
    /// - Parameters:
    ///   - error: An error describing the problem with the JSON.
    case MalformedJSON(error: ErrorType)
    
    /// The JSON is valid, but was not an object when it was expected to be.
    case NotJSONObject

    /// The JSON is a valid JSON object, but is missing the `access_token` field.
    case MissingAccessTokenField
}

/// Contains data returned by the server for a failed authorization.
public struct ErrorData {
    /// The string containing the well-known error types for OAuth 2.0
    public let error: String
    
    /// The string containing a human-readable message describing the error.
    public let errorDescription: String?
    
    /// The URL to a web page containing additional information about the error.
    public let errorURI: NSURL?
    
    /// Decodes a JSON object into an `AuthorizationData` model object
    /// - Parameters:
    ///   - json: An object that was parsed from JSON.
    public static func decode(json: AnyObject) throws -> ErrorData
    {
        guard let dict = json as? NSDictionary else { throw ErrorDataInvalid.NotJSONObject }
        guard let error = dict["error"] as? String else { throw ErrorDataInvalid.MissingErrorField }
        let errorDescription = dict["error_description"] as? String
        let errorURIString = dict["error_uri"] as? String
        let errorURI = errorURIString != nil ? NSURL(string: errorURIString!) : nil
        return ErrorData(error: error, errorDescription: errorDescription, errorURI: errorURI)
    }
}

/// Enumerates the types of failures that can be encountered when attempting to parse error data JSON.
public enum ErrorDataInvalid : ErrorType {
    /// The data is not available or empty.
    case Empty
    
    /// The data is not valid UTF-8.
    case NotUTF8
    
    /// The data is not JSON, or is malformed with syntax errors.
    /// - Parameters:
    ///   - error: An error describing the problem with the JSON.
    case MalformedJSON(error: ErrorType)
    
    /// The JSON is valid, but was not an object when it was expected to be.
    case NotJSONObject
    
    /// The JSON is a valid JSON object, but is missing the `error` field.
    case MissingErrorField
}

/// Contains information about the cause of an authorization failure.
public enum AuthorizationFailure : ErrorType {
    /// Expected parameters were not present in the URI that the server redirected to.
    case MissingParametersInRedirectionURI
    
    /// Unexpected HTTP response from server.
    /// - Parameters:
    ///   - response: The HTTP response received from the server. Can be inspected to
    ///               attempt to determine the root cause.
    case UnexpectedServerResponse(response: NSHTTPURLResponse)
    
    /// Represents the OAuth 2.0 protocol error `invalid_request`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthInvalidRequest(description: String?)

    /// Represents the OAuth 2.0 protocol error `unauthorized_client`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthUnauthorizedClient(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `access_denied`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthAccessDenied(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `unsupported_response_type`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthUnsupportedResponseType(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `invalid_scope`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthInvalidScope(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `server_error`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthServerError(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `temporarily_unavailable`.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthTemporarilyUnavailable(description: String?)
    
    /// Server returned a string in the `error` parameter that is not listed in the OAuth RFC.
    /// - Parameters:
    ///   - description: The contents of the `error_description` parameter returned by the server, if available.
    case OAuthUnknownError(description: String?)
}