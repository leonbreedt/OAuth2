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

extension String {
    /// Attempts to parse this string as JSON and returns the parsed object if successful.
    func parseAsJSONObject() throws -> AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }
    
    /// Parses this string as if it was URL encoded form data, into a dictionary of name value pairs representing each
    /// field.
    func parseAsURLEncodedFormData() -> [String: String] {
        var dict: [String: String] = [:]
        for field in componentsSeparatedByString("&") {
            let kvp = field.componentsSeparatedByString("=")
            if kvp.count != 2 { continue }
            dict[kvp[0]] = kvp[1].urlDecodedString
        }
        return dict
    }
    
    /// Parses this string as an HTTP Content-Type header.
    func parseAsHTTPContentTypeHeader() -> (contentType: String, parameters: [String: String]) {
        let headerComponents = componentsSeparatedByString(";")
            .map { $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) }
        if headerComponents.count > 1 {
            let parameters = headerComponents[1..<headerComponents.count]
                .map { $0.componentsSeparatedByString("=") }
                .toDictionary { ($0[0], $0[1]) }
            return (contentType: headerComponents[0], parameters: parameters)
        } else {
            return (contentType: headerComponents[0], parameters: [:])
        }
    }
    
    /// Decodes a URL encoded string, as well as replacing any occurrences of `+` with a space. Returns the original string
    /// if any error occurs while decoding.
    var urlDecodedString: String {
        return NSString(string: self).stringByRemovingPercentEncoding?.stringByReplacingOccurrencesOfString("+", withString: " ") ?? self
    }
    
    /// Encodes a string into a format suitable for using in URL query parameter values, or form POST parameter values.
    var queryUrlEncodedString: String? {
        return NSString(string: self).stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }
}


