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
    /// - Throws: Throws an `NSError` describing the reason for failure if the JSON could not be parsed.
    /// - Returns: The parsed JSON object, or `nil` if the `NSData` object could not be created from
    ///   the string.
    func parseAsJSONObject() throws -> AnyObject? {
        if let data = dataUsingEncoding(NSUTF8StringEncoding) {
            return try NSJSONSerialization.JSONObjectWithData(data,
                                                              options: NSJSONReadingOptions(rawValue: 0))
        }
        return nil
    }

    /// Parses this string as if it was URL encoded form data, into a dictionary of name value
    /// pairs representing each field.
    /// - Returns: A `[String: String]` dictionary containing the name value pairs.
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
    /// - Returns: A `(mimeType:, encoding:)` tuple containing the parsed MIME type and
    ///            encoding values.
    func parseAsHTTPContentTypeHeader() -> (mimeType: String, encoding: UInt) {
        let headerComponents =
            componentsSeparatedByString(";")
                .map { $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) }
        if headerComponents.count > 1 {
            let parameters = headerComponents[1..<headerComponents.count]
                .map { $0.componentsSeparatedByString("=") }
                .toDictionary { ($0[0], $0[1]) }

            // Default according to RFC is ISO-8859-1, but probably nothing obeys that, so default
            // to UTF-8 instead.
            var encoding = NSUTF8StringEncoding
            if let charset = parameters["charset"], parsedEncoding = charset.parseAsStringEncoding() {
                encoding = parsedEncoding
            }

            return (mimeType: headerComponents[0], encoding: encoding)
        } else {
            return (mimeType: headerComponents[0], encoding: NSUTF8StringEncoding)
        }
    }

    /// Returns Cocoa encoding identifier for the encoding name in this string.
    // swiftlint:disable cyclomatic_complexity
    func parseAsStringEncoding() -> UInt? {
        switch lowercaseString {
        case "iso-8859-1", "latin1": return NSISOLatin1StringEncoding
        case "iso-8859-2", "latin2": return NSISOLatin2StringEncoding
        case "iso-2022-jp": return NSISO2022JPStringEncoding
        case "shift_jis": return NSShiftJISStringEncoding
        case "us-ascii": return NSASCIIStringEncoding
        case "utf-8": return NSUTF8StringEncoding
        case "utf-16": return NSUTF16StringEncoding
        case "utf-32": return NSUTF32StringEncoding
        case "utf-32be": return NSUTF32BigEndianStringEncoding
        case "utf-32le": return NSUTF32LittleEndianStringEncoding
        case "windows-1250": return NSWindowsCP1250StringEncoding
        case "windows-1251": return NSWindowsCP1251StringEncoding
        case "windows-1252": return NSWindowsCP1252StringEncoding
        case "windows-1253": return NSWindowsCP1253StringEncoding
        case "windows-1254": return NSWindowsCP1254StringEncoding
        case "x-mac-roman": return NSMacOSRomanStringEncoding
        default:
            return nil
        }
    }
    // swiftlint:enable cyclomatic_complexity


    /// Decodes a URL encoded string, as well as replacing any occurrences of `+`
    /// with a space. Returns the original string if any error occurs while decoding.
    var urlDecodedString: String {
        return NSString(string: self)
            .stringByRemovingPercentEncoding?
            .stringByReplacingOccurrencesOfString("+", withString: " ") ?? self
    }

    /// Encodes a string into a format suitable for using in URL query parameter
    /// values, or form POST parameter values.
    var queryUrlEncodedString: String? {
        return NSString(string: self)
            .stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
    }
}
