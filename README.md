# OAuth2 [![License](https://img.shields.io/badge/license-Apache%202.0-lightgrey.svg)](https://raw.githubusercontent.com/bitserf/OAuth2/master/LICENSE) [![Build Status](https://travis-ci.org/bitserf/OAuth2.svg)](https://travis-ci.org/bitserf/FavIcon) [![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Tiny little library to perform OAuth 2.0 flows from Swift.

## Features

- Support for `authorization_code` three-legged OAuth 2.0 flows

    - Uses `WKWebView` when displaying a web-browser for the user to log in with

    - Does not require registering custom URL schemes to handle the redirection by
      the server, instead intercepts it directly on the `WKWebView`.

    - If the default `WKWebView` implementation is not satisfactory, allows complete
      customization of how the user is logged in to the authorization service:
      Just pass through the `createWebViewController:` parameter to
      `OAuth2.authorize()`, and have it return an adopter of the
      `WebViewControllerType` protocol.

- Support for `client_credential` two-legged OAuth 2.0 flows

- Support for `refresh_token` two-legged OAuth 2.0 flows

I have tested the library with Google, Facebook and SoundCloud logins. 

*NOTE:* Since Twitter uses the more complex OAuth 1.0, you will need a different
library if you want to support Twitter's flavour of OAuth.

## Usage

You will need the OAuth authorization URL and token URL for the service you are
trying to connect to. 

You will also need the client ID and client secret for your application,
usually found in the developer portal of the service.  Google and Facebook call
them _app ID_ and _app secret_, other providers may use different terminology.

Lastly, if you use the `authorization_code` OAuth 2.0 flow (the one that
requires a user to log in to the service with a web browser, and grant your
application permission), you will need a redirection URL.

This URL should not actually exist for a non-web application, so feel free to
use something like `https://localhost/oauth`. It's a URL the authorization
service will attempt redirect to, in order to provide information which will be
used to issue an access token.

This library will intercept the redirect and handle everything for you so you
just get back a nice packaged up Swift object that tells you whether
authentication succeeded or failed.

Enough talk, how about an example?

## Example

This is an `authorization_code` example.

```swift
    let request = AuthorizationCodeRequest(
        authorizationURL: "https://endpoint.com/auth"
        tokenURL: "https://endpoint.com/token",
        clientId: "YOUR-CLIENT-ID",
        clientSecret: "YOUR-SECRET",
        redirectURL: "https://localhost/oauth")!
    OAuth2.authorize(request) { response in
        switch response {
        case .Success(let data):
            let token = data.accessToken
            // Do something with token, like call an API
            if let refreshToken = data.refreshToken {
                // Save refresh token if provided, `OAuth2.refresh()` can be used
                // to avoid a full re-authentication by the user if the access
                // token expires.
            }
            break
        case .Failure(let error):
            // Authorization failed, `error` is an ErrorType. It may be an 
            // `AuthorizationFailure`, in which case you can check which 
            // well-known OAuth error occurred programmatically.
            // It may also be an `NSError`, if the `NSURLSession` data task
            // failed.
            break
        }
    }
```

As you can see, the library uses a `request:completion:` style, never blocking
the caller. The completion block you supply may be called on a background
queue, so you should send any work touching UIKit to the main queue using
something like `dispatch_async(dispatch_get_main_queue()) {}`.


## More Information

A sample application is included in `OAuth2Example`, ready for you to test
Google, Facebook and SoundCloud authentication. Just fill in the IDs and
secrets for your registered application first.

## License
Apache 2.0
