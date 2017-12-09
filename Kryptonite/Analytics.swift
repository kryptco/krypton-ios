//
//  Analytics.swift
//  Kryptonite
//
//  Created by Kevin King on 10/22/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import SwiftHTTP

class Analytics {

    static let mutex: Mutex = Mutex()

    static var enabled : Bool {
        mutex.lock()
        defer { mutex.unlock() }
        if let isDisabledObject = UserDefaults.group?.object(forKey: analyticsDisabledKey),
            let isDisabled = isDisabledObject as? Bool {
            return !isDisabled
        }
        return !Platform.isDebug
    }

    static var publishedEmail:String? {
        get {
            return UserDefaults.group?.string(forKey: "analytics_email_sent")
        } set (e) {
            UserDefaults.group?.set(e, forKey: "analytics_email_sent")
            UserDefaults.group?.synchronize()
        }
    }

    static let analyticsDisabledKey = "analytics_disabled"
    class func set(disabled: Bool) {
        postEvent(category: "analytics", action: disabled ? "disabled" : "enabled", forceEnable: true)

        mutex.lock()
        defer { mutex.unlock() }
        UserDefaults.group?.set(disabled, forKey: analyticsDisabledKey)
        UserDefaults.group?.synchronize()
    }

    class func migrateAnalyticsDisabled() {
        mutex.lock()
        defer { mutex.unlock() }

        if UserDefaults.standard.bool(forKey: analyticsDisabledKey) {
            UserDefaults.group?.set(true, forKey: analyticsDisabledKey)
            UserDefaults.group?.synchronize()
            UserDefaults.standard.set(false, forKey: analyticsDisabledKey)
            UserDefaults.standard.synchronize()
        }
    }

    static var cachedPhoneModel: String?
    class var phoneModel : String? {
        mutex.lock()
        defer { mutex.unlock() }
        if let cachedPhoneModel = cachedPhoneModel {
            return cachedPhoneModel
        }

        var systemInfo : utsname = utsname();
        uname(&systemInfo);

        withUnsafePointer(to: &systemInfo.machine.0, {
            if let phoneModel = NSString(cString: $0, encoding: String.Encoding.utf8.rawValue){
                cachedPhoneModel = phoneModel as String
            }
        })
        return cachedPhoneModel
    }

    class var userAgent : String? {
        return UserDefaults.group?.string(forKey: "UserAgent")
    }

    static let analyticsUserIDKey = "analyticsUserID"

    class var userID : String {
        if let userID = UserDefaults.group?.string(forKey: analyticsUserIDKey) {
            return userID
        }
        mutex.lock()
        defer { mutex.unlock() }
        var randBytes = [UInt8](repeating: 0, count: 16)
        let _ = SecRandomCopyBytes(kSecRandomDefault, randBytes.count, &randBytes)
        let id = Data(randBytes).toBase64()
        UserDefaults.group?.set(id, forKey: analyticsUserIDKey)
        UserDefaults.group?.synchronize()
        return id
    }

    class func migrateOldIDIfExists() {
        if let oldUserID = UserDefaults.standard.string(forKey: analyticsUserIDKey) {
            mutex.lock()
            defer { mutex.unlock() }
            UserDefaults.group?.set(oldUserID, forKey: analyticsUserIDKey)
            UserDefaults.group?.synchronize()
            UserDefaults.standard.set(nil, forKey: analyticsUserIDKey)
            UserDefaults.standard.synchronize()
        }
    }

    class func sendEmailToTeamsIfNeeded(email:String) {
        guard enabled else {
            return
        }
        guard Analytics.publishedEmail != email else {
            return
        }
        
        HTTP.PUT("https://teams.krypt.co", parameters: ["id": userID, "email": email]) { response in
            
            if let error = response.error {
                log("put email error: \(error)", .error)
                return
            }
            
            guard let status = response.statusCode
            else {
                log("put email no status code", .error)
                return
            }
            
            guard (200..<300).contains(status) else {
                log("bad status code: \(status)", .error)
                return
            }
            
            log("email published success")
            Analytics.publishedEmail = email
        }
    }

    private class func post(params: [String:String], forceEnable:Bool = false) {
        guard forceEnable || enabled else {
            return
        }

        var analyticsParams : [String:String] = [
            "v": "1",
            "tid": Properties.trackingID,
            "cid": userID,
            "cd4": "iOS",
            "cd5": "iOS \(UIDevice.current.systemVersion)",
            "cd7": userID,
            "cd9": Properties.currentVersion.string,
            ]
        if let phoneModel = phoneModel {
            analyticsParams["cd6"] = phoneModel
        }

        log("\(analyticsParams)")
        for (key, val) in params {
            analyticsParams[key] = val
        }

        var headers : [String:String] = [:]

        if let userAgent = Analytics.userAgent {
            analyticsParams["ua"] = userAgent
            headers["User-Agent"] = userAgent
        }

        HTTP.POST("https://www.google-analytics.com/collect", parameters: analyticsParams, headers: headers)
        { response in
            if let err = response.error {
                log("error: \(err.localizedDescription)")
                return
            }
            if let status = response.statusCode {
                if (200..<300).contains(status) {
                    log("analytics success")
                    return
                }
                log("analytics failure \(status)")
            }
        }

    }

    class func postPageView(page: String) {
        log("page \(page)")
        let params : [String:String] = [
            "t": "pageview",
            "dt": page,
            "dp": "/" + page,
            "dh": "co.krypt.kryptonite",
            ]
        dispatchAsync{ Analytics.post(params: params) }
    }

 

    class func postEvent(category:String, action:String, label:String? = nil, value: UInt? = nil, forceEnable:Bool = false) {
        var params : [String:String] = [
            "t": "event",
            "ec": category,
            "ea": action,
        ]
        if let label = label {
            params["el"] = label
        }
        if let value = value {
            params["ev"] = String(value)
        }

        dispatchAsync{ Analytics.post(params: params, forceEnable:forceEnable) }
    }

    class func appLaunch() {
        let params : [String:String] = [
            "t": "event",
            "ec": "app",
            "ea": "launch",

            "sc": "start",
            ]

        dispatchAsync {
            Analytics.post(params: params)
        }
    }


    class func appOpen() {
        let params : [String:String] = [
            "t": "event",
            "ec": "app",
            "ea": "open",

            "sc": "start",
            ]

        dispatchAsync {
            Analytics.post(params: params)
        }
    }

    class func appClose() {
        let params : [String:String] = [
            "t": "event",
            "ec": "app",
            "ea": "close",

            "sc": "end",
            ]

        dispatchAsync {
            Analytics.post(params: params)
        }
    }
}

