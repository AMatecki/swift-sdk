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

import UIKit
import Optimizely
#if os(iOS)
import Amplitude_iOS
#endif


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let sdkKey = "FCnSegiEkRry9rhVMroit4"
    let datafileName = "demoTestDatafile"
    let experimentKey = "background_experiment"
    let eventKey = "sample_conversion"
    
    let userId = String(Int.random(in: 0..<100000))
    let attributes: [String : Any?] = ["browser_type": "safari", "bool_attr": false]
    
    var window: UIWindow?
    var optimizely: OptimizelyClient!
    var storyboard: UIStoryboard {
        #if os(iOS)
        return UIStoryboard(name: "iOSMain", bundle: nil)
        #else
        return UIStoryboard(name: "tvOSMain", bundle: nil)
        #endif
    }
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        // most of the third-party integrations only support iOS, so the sample code is only targeted for iOS builds
        #if os(iOS)
            Amplitude.instance().initializeApiKey("YOUR_API_KEY_HERE")
        #endif

        // initialize SDK in one of these two ways:
        // (1) asynchronous SDK initialization (RECOMMENDED)
        //     - fetch a JSON datafile from the server
        //     - network delay, but the local configuration is in sync with the server experiment settings
        // (2) synchronous SDK initialization
        //     - initialize immediately with the given JSON datafile or its cached copy
        //     - no network delay, but the local copy is not guaranteed to be in sync with the server experiment settings
        
        initializeOptimizelySDKAsynchronous()
    }
    
    // MARK: - Initialization Examples
    
    func initializeOptimizelySDKAsynchronous() {
        optimizely = OptimizelyClient(sdkKey: sdkKey)
        
        optimizely.initializeSDK { result in
            switch result {
            case .failure(let error):
                print("Optimizely SDK initiliazation failed: \(error)")
                self.optimizely = nil
            case .success:
                print("Optimizely SDK initialized successfully!")
            }
            
            DispatchQueue.main.async {
                self.startWithRootViewController()
            }
        }
    }
    
    func initializeOptimizelySDKSynchronous() {
        guard let localDatafilePath = Bundle.main.path(forResource: datafileName, ofType: "json") else {
            fatalError("Local datafile cannot be found")
        }
        
        optimizely = OptimizelyClient(sdkKey: sdkKey)

        do {
            let datafileJSON = try String(contentsOfFile: localDatafilePath, encoding: .utf8)
            try optimizely!.initializeSDK(datafile: datafileJSON)
            print("Optimizely SDK initialized successfully!")
        } catch {
            print("Optimizely SDK initiliazation failed: \(error)")
            optimizely = nil
        }
        
        startWithRootViewController()
    }
    
    func initializeOptimizelySDKWithCustomization() {
        // customization example (optional)
        
        let customLogger = CustomLogger()
        // 30 sec interval may be too frequent. This is for demo purpose.
        // This should be should be much larger (default = 10 mins).
        let customDownloadIntervalInSecs = 30
        
        optimizely = OptimizelyClient(sdkKey: sdkKey,
                                       logger: customLogger,
                                       periodicDownloadInterval: customDownloadIntervalInSecs)
        
        // notification listeners
        
        _ = optimizely.notificationCenter.addDecisionNotificationListener(decisionListener: { (type, userId, attributes, decisionInfo) in
            print("Received decision notification: \(type) \(userId) \(String(describing: attributes)) \(decisionInfo)")
         })
        
        _ = optimizely.notificationCenter.addTrackNotificationListener(trackListener: { (eventKey, userId, attributes, eventTags, event) in
            print("Received track notification: \(eventKey) \(userId) \(String(describing: attributes)) \(String(describing: eventTags)) \(event)")
            
            #if os(iOS)
            
            // Amplitude example
            let propertyKey = "[Optimizely] " + eventKey
            let identify = AMPIdentify()
            identify.set(propertyKey, value: userId as NSObject?)
            // Track event (optional)
            let eventIdentifier = "[Optimizely] " + eventKey + " - " + userId
            Amplitude.instance().logEvent(eventIdentifier)
            
            #endif
        })
        
        _ = optimizely.notificationCenter.addDatafileChangeNotificationListener(datafileListener: { (data) in
            DispatchQueue.main.async {
                #if os(iOS)
                if let controller = self.window?.rootViewController {
                    let alert = UIAlertController(title: "Datafile Changed", message: nil, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default))
                    controller.present(alert, animated: true)
                }
                #else
                print("Datafile changed")
                #endif
                
                if let controller = self.window?.rootViewController as? VariationViewController {
                    //controller.showCoupon = toggle == FeatureFlagToggle.on ? true : false;
                    if let showCoupon = try? self.optimizely.isFeatureEnabled(featureKey: "show_coupon", userId: self.userId) {
                        controller.showCoupon = showCoupon
                    }
                }
            }
        })

        // initialize SDK
        
        optimizely!.initializeSDK { result in
            switch result {
            case .failure(let error):
                print("Optimizely SDK initiliazation failed: \(error)")
                self.optimizely = nil
            case .success:
                print("Optimizely SDK initialized successfully!")
            }
            
            DispatchQueue.main.async {
                self.startWithRootViewController()
            }
        }
    }

    // MARK: - ViewControl
    
    func startWithRootViewController() {
        do {
            let variationKey = try optimizely.activate(experimentKey: experimentKey,
                                                       userId: userId,
                                                       attributes: attributes)
            openVariationView(variationKey: variationKey)
        } catch OptimizelyError.variationUnknown(userId, experimentKey) {
            print("Optimizely SDK activation cannot map this user to experiemnt")
            openVariationView(variationKey: nil)
        } catch {
            print("Optimizely SDK activation failed: \(error)")
            openFailureView()
        }
    }
    
    func openVariationView(variationKey: String?) {
        let variationViewController = storyboard.instantiateViewController(withIdentifier: "VariationViewController") as! VariationViewController
        
        if let showCoupon = try? optimizely.isFeatureEnabled(featureKey: "show_coupon", userId: userId) {
            variationViewController.showCoupon = showCoupon
        }
        
        variationViewController.optimizely = optimizely
        variationViewController.userId = userId
        variationViewController.variationKey = variationKey
        variationViewController.eventKey = eventKey

        window?.rootViewController = variationViewController
    }

    func openFailureView() {
        window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "FailureViewController")
    }
    
    // MARK: - AppDelegate
    
    func applicationWillResignActive(_ application: UIApplication) {
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
    }
    
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        
        // add background fetch task here
        
        completionHandler(.newData)
    }
}

