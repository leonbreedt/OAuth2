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

extension NSURL {
    /// Returns a dictionary of the query parameters of this URL.
    var queryParameters : [String: String] {
        let components = NSURLComponents(string: absoluteString)
        return components?
            .queryItems?
            .filter {$0.value != nil}
            .map { ($0.name, $0.value!) }
            .toDictionary { ($0.0, $0.1) } ?? Dictionary<String, String>()
    }
}
