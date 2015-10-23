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

extension NSHTTPURLResponse {
    func dumpHeadersAndBody(bodyData: NSData?) -> String {
        let statusCode = self.statusCode ?? 0
        var result = "HTTP \(statusCode ?? 0) \(NSHTTPURLResponse.localizedStringForStatusCode(statusCode))\n"
        for (name, value) in allHeaderFields {
            result += "\(name): \(value)\n"
        }
        if let data = bodyData {
            if let bodyString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                result += "\n\(bodyString)\n"
            } else {
                result += "\n<\(data.length) byte(s)>\n"
            }
        }
        return result
    }
}