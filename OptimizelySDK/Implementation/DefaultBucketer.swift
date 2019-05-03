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

class DefaultBucketer : OPTBucketer {
    let MAX_TRAFFIC_VALUE = 10000;
    let HASH_SEED = 1;
    let MAX_HASH_SEED:UInt64 = 1
    var MAX_HASH_VALUE:UInt64?
    
    private lazy var logger = HandlerRegistryService.shared.injectLogger()
    
    init() {
        MAX_HASH_VALUE = MAX_HASH_SEED << 32
    }

    func bucketExperiment(config:ProjectConfig, experiment: Experiment, bucketingId: String) -> Variation? {
        var mutexAllowed = true
        
        // check for mutex
        
        let group = config.project.groups.filter({
            var g = $0
            guard let _ = g.experimentMap[experiment.id] else {
                return false
            }
            return true
        }).first
        
        if let group = group {
            switch group.policy {
            case .overlapping:
                break;
            case .random:
                let mutexExperiment = bucketToExperiment(config: config, group: group, bucketingId: bucketingId)
                if let mutexExperiment = mutexExperiment {
                    if mutexExperiment.id == experiment.id {
                        mutexAllowed = true
                        logger?.i(.userBucketedIntoExperimentInGroup(bucketingId, experiment.key, group.id))
                    } else {
                        mutexAllowed = false
                        logger?.i(.userNotBucketedIntoExperimentInGroup(bucketingId, experiment.key, group.id))
                    }
                } else {
                    mutexAllowed = false
                    logger?.i(.userNotBucketedIntoAnyExperimentInGroup(bucketingId, group.id))
                }
            }
        }
        
        if !mutexAllowed { return nil }
        
        // bucket to variation only if experiment passes Mutex check

        if let variation = bucketToVariation(experiment:experiment, bucketingId:bucketingId) {
            logger?.i(.userBucketedIntoVariationInExperiment(bucketingId, experiment.key, variation.key))
            return variation
        } else {
            logger?.i(.userNotBucketedIntoVariationInExperiment(bucketingId, experiment.key))
            return nil
        }
    }
    
    func bucketToExperiment(config:ProjectConfig, group: Group, bucketingId: String) -> Experiment? {
        let hashId = makeHashIdFromBucketingId(bucketingId: bucketingId, entityId: group.id)
        let bucketValue = self.generateBucketValue(bucketingId: hashId)
        logger?.d(.userAssignedToExperimentBucketValue(bucketValue, bucketingId))
        
        if group.trafficAllocation.count == 0 {
            logger?.e(.groupHasNoTrafficAllocation(group.id))
            return nil;
        }
        
        for trafficAllocation in group.trafficAllocation where bucketValue <= trafficAllocation.endOfRange {
            if let experiment = config.getExperiment(id: trafficAllocation.entityId) {
                return experiment
            } else {
                logger?.e(.userBucketedIntoInvalidExperiment(trafficAllocation.entityId))
                return nil
            }
        }
        
        return nil
    }
    
    func bucketToVariation(experiment:Experiment, bucketingId:String) -> Variation? {
        let hashId = makeHashIdFromBucketingId(bucketingId: bucketingId, entityId: experiment.id)
        let bucketValue = generateBucketValue(bucketingId: hashId)
        logger?.d(.userAssignedToVariationBucketValue(bucketValue, bucketingId))

        if experiment.trafficAllocation.count == 0 {
            logger?.e(.experimentHasNoTrafficAllocation(experiment.key))
            return nil
        }
        
        for trafficAllocation in experiment.trafficAllocation where (bucketValue <= trafficAllocation.endOfRange) {
                // propagate errors and logs for unknown variation
                if let variation = experiment.getVariation(id: trafficAllocation.entityId) {
                    return variation
                } else {
                    logger?.e(.userBucketedIntoInvalidVariation(trafficAllocation.entityId))
                    return nil
                }
        }
        
        return nil;
    }
    
    func generateBucketValue(bucketingId: String) -> Int {
        let ratio = Double(generateUnsignedHashCode32Bit(hashId: bucketingId)) /  Double(MAX_HASH_VALUE!)
        return Int(ratio * Double(MAX_TRAFFIC_VALUE))
    }
    
    func makeHashIdFromBucketingId(bucketingId: String, entityId: String) -> String {
        return bucketingId + entityId
    }
    
    func generateUnsignedHashCode32Bit(hashId:String) -> UInt32 {
        let result = MurmurHash3.doHash32(key: hashId, maxBytes: hashId.lengthOfBytes(using: String.Encoding.utf8), seed: 1)
        return result;
    }
    
    
}
