//
//  AnalyticsStub.swift
//  Kryptonite
//
//  Created by Kevin King on 4/4/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
@testable import Kryptonite

class Analytics {

    static let mutex: Mutex = Mutex()

    static var enabled : Bool {
        mutex.lock()
        defer { mutex.unlock() }
        return !(UserDefaults.group?.bool(forKey: "analytics_disabled") ?? false)
    }

    static var publishedEmail:String? {
        get {
            return UserDefaults.group?.string(forKey: "analytics_email_sent")
        } set (e) {
            UserDefaults.group?.set(e, forKey: "analytics_email_sent")
            UserDefaults.group?.synchronize()
        }
    }
    
    class func set(disabled: Bool) {
        postEvent(category: "analytics", action: disabled ? "disabled" : "enabled", forceEnable: true)

        mutex.lock()
        defer { mutex.unlock() }
        UserDefaults.group?.set(disabled, forKey: "analytics_disabled")
        UserDefaults.group?.synchronize()
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
        return ""
    }

    class func migrateOldIDIfExists() {
    }

    class func sendEmailToTeamsIfNeeded(email:String) {
    }

    private class func post(params: [String:String], forceEnable:Bool = false) {
    }

    class func postPageView(page: String) {
    }

 

    class func postEvent(category:String, action:String, label:String? = nil, value: UInt? = nil, forceEnable:Bool = false) {
    }

    class func appLaunch() {
    }


    class func appOpen() {
    }

    class func appClose() {
    }
}
