//
//  Response.swift
//  OAuth2
//
//  Created by Leon Breedt on 23/09/15.
//  Copyright © 2015 Leon Breedt. All rights reserved.
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