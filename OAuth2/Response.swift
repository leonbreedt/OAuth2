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
    ///   - data: An `AuthorizationData` containing the tokens and other information returned by the server.
    case Success(data: AuthorizationData)
    
    /// A failed authorization.
    /// - Parameters:
    ///   - failure: An `ErrorType` containing more details about the cause of the failure.
    case Failure(failure: ErrorType)
}

/// Contains data returned by the server for a successful authorization.
public struct AuthorizationData {
    /// The token that can be used to access the resources protected by OAuth.
    public let accessToken: String
    
    /// The refresh token that can be used to obtain a replacement token when the access token expires.
    public let refreshToken: String?
    
    /// The amount of time, in seconds, until the access token expires.
    public let expiresInSeconds: Int?
}

/// Enumerates the types of failures that can be encountered when attempting to parse authorization data.
public enum AuthorizationDataInvalid : ErrorType {
    /// The data is not available or empty.
    case Empty
    
    /// The data is not valid UTF-8.
    case NotUTF8
    
    /// The data is not JSON, or is malformed with syntax errors.
    case MalformedJSON(error: ErrorType)
    
    /// The JSON is valid, but was not an object when it was expected to be.
    case NotJSONObject

    /// The JSON is a valid JSON object, but is missing the `access_token` field.
    case MissingAccessToken
}

/// Contains information about the cause of an authorization failure.
public enum AuthorizationFailure : ErrorType {
    /// Expected parameters were not present in the URI that the server redirected to.
    case MissingParametersInRedirectionURI
    
    /// Invalid HTTP status code from server.
    case InvalidResponseStatusCode
    
    /// Represents the OAuth 2.0 protocol error `invalid_request`.
    case OAuthInvalidRequest(description: String?)

    /// Represents the OAuth 2.0 protocol error `unauthorized_client`.
    case OAuthUnauthorizedClient(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `access_denied`.
    case OAuthAccessDenied(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `unsupported_response_type`.
    case OAuthUnsupportedResponseType(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `invalid_scope`.
    case OAuthInvalidScope(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `server_error`.
    case OAuthServerError(description: String?)
    
    /// Represents the OAuth 2.0 protocol error `temporarily_unavailable`.
    case OAuthTemporarilyUnavailable(description: String?)
    
    /// Server returned a string in the `error` parameter that is not listed in the OAuth RFC.
    case OAuthUnknownError(description: String?)
    
    /// An authorization failure having a `String` describing the cause of the failure.
    /// - Parameters:
    ///   - reason: A description of the cause of the failure.
    case WithReason2(reason: String)
    
    /// An authorization failure having a `String` describing the cause of the failure.
    /// - Parameters:
    ///   - message: A short description of the cause of the failure.
    ///   - message: A human-readable description of the cause of the failure.
    case WithDetails2(message: String, details: String)
}