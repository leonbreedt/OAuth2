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

/// Represents the response to an authentication attempt.
public enum Response {
    /// A successful authentication attempt.
    /// - Parameters:
    ///   - data: An `AuthenticationData` containing the tokens and other information returned by the server.
    case Success(data: AuthenticationData)
    
    /// A failed authentication attempt.
    /// - Parameters:
    ///   - failure: An `AuthenticationFailure` containing more details about the cause of the failure.
    case Failure(failure: AuthenticationFailure)
}

/// Contains data returned by the server for a successful authentication.
public struct AuthenticationData {
    /// The token that can be used to access resources protected by OAuth.
    let accessToken: String
    
    /// The refresh token that can be used to obtain a replacement access token when it expires.
    let refreshToken: String?
    
    /// The amount of time, in seconds, until the access token expires.
    let expiresIn: Int?
}

/// Contains information about the cause of an authentication failure.
public enum AuthenticationFailure {
    /// An authentication failure having a `String` describing the cause of the failure.
    /// - Parameters:
    ///   - reason: A human-readable description of the reason for the failure.
    case WithReason(reason: String)

    /// An authentication failure where an `NSError` was thrown during the course of communicating with the server.
    /// - Parameters:
    ///   - error: The error that was thrown.
    case WithError(error: NSError)
}