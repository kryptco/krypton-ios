//
//  AppDelegate.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

//

import UIKit
import UserNotifications

struct InvalidNotification:Error{}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var pendingLink:Link?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {

        Analytics.migrateOldIDIfExists()
        Analytics.migrateAnalyticsDisabled()
                
        Resources.makeAppearences()
        
        if !API.provision() {
            log("API provision failed.", LogType.error)
        }
        
        AWSLogger.default().logLevel = .none
        TransportControl.shared.add(sessions: SessionManager.shared.all)
                
        // check for link
        if  let url = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL,
            let link = Link(url: url)
        {
            pendingLink = link
        }
        
        //Weird behavior when we don't re-register?
        if application.isRegisteredForRemoteNotifications {
            self.registerPushNotifications()
        }

        Analytics.appLaunch()
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        return true
    }
    
    //MARK: App Lifecycle
    
    func applicationWillResignActive(_ application: UIApplication) {
        LogManager.shared.saveContext()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        TransportControl.shared.willEnterBackground()
        Analytics.appClose()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        TransportControl.shared.willEnterForeground()
        
        application.applicationIconBadgeNumber = 1
        application.applicationIconBadgeNumber = 0
        Analytics.setUserAgent()
        Analytics.appOpen()
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        if let pending = Policy.lastPendingAuthorization {
            log("requesting pending authorization")
            Policy.requestUserAuthorization(session: pending.session, request: pending.request)
        }
        //  Send email again if not sent succesfully
        if let email = try? KeyManager.sharedInstance().getMe() {
            dispatchAsync { Analytics.sendEmailToTeamsIfNeeded(email: email) }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        TransportControl.shared.willEnterBackground()
        LogManager.shared.saveContext()
    }
}
