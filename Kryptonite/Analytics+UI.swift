//
//  Analytics+UI.swift
//  Kryptonite
//
//  Created by Alex Grinman on 2/17/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation

extension Analytics {
    
    class func setUserAgent() {
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        dispatchMain {
            if var userAgent = UIWebView().stringByEvaluatingJavaScript(from: "navigator.userAgent") {
                if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    userAgent += " Version/\(build)"
                }
                UserDefaults.group?.set(userAgent, forKey: "UserAgent")
                UserDefaults.group?.synchronize()
                log("Set UserAgent to \(userAgent)")
            }
        }
    }
    
    class func postControllerView(clazz: String) {
        
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        let clazz = clazz.replacingOccurrences(of: "Kryptonite.", with: "")
            .replacingOccurrences(of: "Controller", with: "")
        
        dispatchAsync { Analytics.postPageView(page: clazz) }
    }
    
    
}
