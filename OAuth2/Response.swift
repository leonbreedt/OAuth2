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
    
    /// A successful authorization, with a code returned to be used with the token issuing server.
    case CodeIssued(code: String)
    
    /// A failed authorization.
    /// - Parameters:
    ///   - failure: An `AuthorizationFailure` containing more details about the cause of the failure.
    case Failure(failure: AuthorizationFailure)
}

/// Contains data returned by the server for a successful authorization.
public struct AuthorizationData {
    /// The token that can be used to access the resources protected by OAuth.
    let accessToken: String
    
    /// The refresh token that can be used to obtain a replacement access token when it expires.
    let refreshToken: String?
    
    /// The amount of time, in seconds, until the access token expires.
    let expiresIn: Int?
}

/// Enumerates the types of failures that can be encountered when attempting to parse authorization data.
public enum AuthorizationDataInvalid : ErrorType {
    /// The JSON is malformed or not valid JSON
    case MalformedJSON
    /// The `access_token` field is missing from the JSON response.
    case MissingAccessToken
}

/// Contains information about the cause of an authorization failure.
public enum AuthorizationFailure {
    /// An authorization failure having a `String` describing the cause of the failure.
    /// - Parameters:
    ///   - reason: A human-readable description of the reason for the failure.
    case WithReason(reason: String)

    /// An authorization failure where an `NSError` was thrown during the course of performing the authorization.
    /// - Parameters:
    ///   - error: The error that was thrown.
    case WithError(error: NSError)
}