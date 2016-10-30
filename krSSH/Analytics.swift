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
        return !UserDefaults.standard.bool(forKey: "analytics_disabled")
    }

    class func set(disabled: Bool) {
        postEvent(category: "analytics", action: disabled ? "disabled" : "enabled", forceEnable: true)

        mutex.lock()
        defer { mutex.unlock() }
        UserDefaults.standard.set(disabled, forKey: "analytics_disabled")
        UserDefaults.standard.synchronize()
    }

    class func setUserAgent() {
        guard UIApplication.shared.applicationState == .active else {
            return
        }
        dispatchMain {
            if var userAgent = UIWebView().stringByEvaluatingJavaScript(from: "navigator.userAgent") {
                if let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                    userAgent += " Version/\(build)"
                }
                UserDefaults.standard.set(userAgent, forKey: "UserAgent")
                UserDefaults.standard.synchronize()
                log("Set UserAgent to \(userAgent)")
            }
        }
    }

    class var userAgent : String? {
        return UserDefaults.standard.string(forKey: "UserAgent")
    }

    class var userID : String {
        if let userID = UserDefaults.standard.string(forKey: "analyticsUserID") {
            return userID
        }
        mutex.lock()
        defer { mutex.unlock() }
        var randBytes = [UInt8](repeating: 0, count: 16)
        let _ = SecRandomCopyBytes(kSecRandomDefault, randBytes.count, &randBytes)
        let id = Data(randBytes).toBase64()
        UserDefaults.standard.set(id, forKey: "analyticsUserID")
        UserDefaults.standard.synchronize()
        return id
    }

    class func sendEmailToTeams(email:String) {
        guard enabled else {
            return
        }
        do{
            let req = try HTTP.PUT("https://teams.krypt.co", parameters: ["id": userID, "email": email])
            req.start { response in
                if let err = response.error {
                    log("error: \(err.localizedDescription)")
                    return
                }
                if let status = response.statusCode {
                    if (200..<300).contains(status) {
                        log("put email success")
                        return
                    }
                    log("put email failure \(status)")
                }
            }
        } catch (let e) {
            log("error publishing email: \(e)")
        }
    }

    class func post(params: [String:String], forceEnable:Bool = false) {
        guard forceEnable || enabled else {
            return
        }
        var analyticsParams : [String:String] = [
            "v": "1",
            "tid": Properties.trackingID,
            "cid": userID,
            ]

        for (key, val) in params {
            analyticsParams[key] = val
        }

        var headers : [String:String] = [:]

        if let userAgent = Analytics.userAgent {
            analyticsParams["ua"] = userAgent
            headers["User-Agent"] = userAgent
        }

        do {
            let req = try HTTP.POST("https://www.google-analytics.com/collect", parameters: analyticsParams, headers: headers)
            req.start { response in
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
        } catch let e {
            log("\(e)")
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

    class func postControllerView(clazz: String) {
        let clazz = clazz.replacingOccurrences(of: "Kryptonite.", with: "")
            .replacingOccurrences(of: "Controller", with: "")

        dispatchAsync { Analytics.postPageView(page: clazz) }
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

