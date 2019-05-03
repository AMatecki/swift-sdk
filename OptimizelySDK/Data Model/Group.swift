/****************************************************************************
* Copyright 2019, Optimizely, Inc. and contributors                        *
*                                                                          *
* Licensed under the Apache License, Version 2.0 (the "License");          *
* you may not use this file except in compliance with the License.         *
* You may obtain a copy of the License at                                  *
*                                                                          *
*    http://www.apache.org/licenses/LICENSE-2.0                            *
*                                                                          *
* Unless required by applicable law or agreed to in writing, software      *
* distributed under the License is distributed on an "AS IS" BASIS,        *
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. *
* See the License for the specific language governing permissions and      *
* limitations under the License.                                           *
***************************************************************************/

import Foundation

struct Group: Codable, Equatable {
    enum Policy: String, Codable {
        case random
        case overlapping
    }
    
    var id: String
    var policy: Policy
    var trafficAllocation: [TrafficAllocation]
    var experiments: [Experiment]
    
    private enum CodingKeys: String, CodingKey {
        case id
        case policy
        case trafficAllocation
        case experiments
    }
    
    lazy var experimentMap:[String:Experiment] = {
        var map:[String:Experiment] = [:]
        experiments.forEach({map[$0.id] = $0 })
        return map
    }()
}

// MARK: - Utils

extension Group {
    
    mutating func getExperiment(id: String) -> Experiment? {
        return self.experimentMap[id]
    }
    
}
