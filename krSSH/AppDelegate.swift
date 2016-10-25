//
//  AppDelegate.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var pendingLink:Link?
    
    var pendingAuthorizationMutex = Mutex()
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
                
        Resources.makeAppearences()
        
        if !API.provision() {
            log("API provision failed.", LogType.error)
        }
        
        AWSLogger.default().logLevel = .none
        Silo.shared.add(sessions: SessionManager.shared.all)
        Silo.shared.startPolling()
                
        // check for link
        if  let url = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL,
            let link = Link(url: url)
        {
            pendingLink = link
        }
        
        //TODO: check for remote notification
        
        if application.isRegisteredForRemoteNotifications {
            self.registerPushNotifications()
        }

        Analytics.appLaunch()
        
        return true
    }
    
    
    func registerPushNotifications() {
        DispatchQueue.main.async {
            let settings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: [Policy.authorizeCategory])
            UIApplication.shared.registerUserNotificationSettings(settings)
        }
    }
    
    func application(_ application: UIApplication, didRegister notificationSettings: UIUserNotificationSettings) {
        if notificationSettings.types != UIUserNotificationType() {
            application.registerForRemoteNotifications()
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let chars = deviceToken.bytes
        var token = ""
        
        for i in 0..<deviceToken.count {
            token += String(format: "%02.2hhx", arguments: [chars[i]])
        }
        
        log("Got token: \(token)")
        
        API().updateSNS(token: token) { (endpoint, err) in
            guard let arn = endpoint else {
                log("AWS SNS error: \(err)", .error)
                return
            }
            
            let res = KeychainStorage().set(key: KR_ENDPOINT_ARN_KEY, value: arn)
            if !res { log("Could not save push ARN", .error) }
            
            API().setEndpointEnabledSNS(endpointArn: arn, completionHandler: { (err) in
                if let err = err {
                    log("AWS SNS endpoint enable error: \(err)", .error)
                    return
                }
            })
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
        log("Push registration failed!", .error)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        
        self.application(application, didReceiveRemoteNotification: userInfo) { (fr) in
            log("handled from other didReceive")
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        
        log("got background notification")
        checkForAppUpdateIfNeededBackground()
        
        guard   let queue = (userInfo["aps"] as? [String: Any])?["queue"] as? QueueName,
                let networkMessageString = (userInfo["aps"] as? [String: Any])?["c"] as? String
        else {
            log("invalid push notification: \(userInfo)", .error)
            completionHandler(.failed)
            return
        }
        
        guard let session = SessionManager.shared.all.filter({ $0.pairing.queue == queue }).first else {
            log("no session for queue name: \(queue)", .error)
            completionHandler(.failed)
            return

        }
        
        do {
            let networkMessage = try NetworkMessage(networkData: networkMessageString.fromBase64())
            let req = try Request(key: session.pairing.symmetricKey, sealed: networkMessage.data)
            try Silo.shared.handle(request: req, session: session, communicationMedium: .RemoteNotification, completionHandler: { completionHandler(.newData) })

        } catch let e {
            log("error creating or sending response: \(e)")
            completionHandler(.failed)
        }
    

    }

    //MARK: Tap local notification
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        
        log("tap local notification")
        
        pendingAuthorizationMutex.lock {
            if
                let sessionID = notification.userInfo?["session_id"] as? String,
                let session = SessionManager.shared.get(id: sessionID),
                let requestJSON = notification.userInfo?["request"] as? JSON,
                let request = try? Request(json: requestJSON)
                
            {
                // if approval notification
                Policy.pendingAuthorization = (session, request)
            }
        }
        
      
        
        
    }
    
    //MARK: Allow/Reject
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, for notification: UILocalNotification, withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
        
        handleAction(userInfo: notification.userInfo, identifier: identifier, completionHandler: completionHandler)
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {
        
        handleAction(userInfo: userInfo, identifier: identifier, completionHandler: completionHandler)
    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable : Any], withResponseInfo responseInfo: [AnyHashable : Any], completionHandler: @escaping () -> Void) {

        handleAction(userInfo: userInfo, identifier: identifier, completionHandler: completionHandler)

    }
    
    func application(_ application: UIApplication,
                     handleActionWithIdentifier identifier: String?,
                     for notification: UILocalNotification,
                     completionHandler: @escaping () -> Void ){
        
        handleAction(userInfo: notification.userInfo, identifier: identifier, completionHandler: completionHandler)
        
    }
    
    func handleAction(userInfo:[AnyHashable : Any]?, identifier:String?, completionHandler:@escaping ()->Void) {
        
        Policy.pendingAuthorization = nil
        
        let signatureAllowed = (identifier != Policy.rejectAction.identifier)
        
        if identifier == Policy.approveTemporaryAction.identifier {
            Policy.allowFor(time: Policy.Interval.oneHour)
        }


        if let identifier = identifier {
            switch identifier {
            case Policy.approveIdentifier:
                Analytics.postEvent(category: "signature", action: "background approve", label: "once")
            case Policy.approveTempIdentifier:
                Analytics.postEvent(category: "signature", action: "background approve", label: "time", value: UInt(Policy.Interval.oneHour.rawValue))
            case Policy.rejectIdentifier:
                Analytics.postEvent(category: "signature", action: "background reject")
            default:
                log("unhandled approval identifier: \(identifier)")
            }
        }


        log("user allows")
        
        guard   let sessionID = userInfo?["session_id"] as? String,
            let session = SessionManager.shared.get(id: sessionID),
            let requestJSON = userInfo?["request"] as? JSON
            else {
                
                log("invalid notification", .error)
                completionHandler()
                return
        }
        
        do {
            let request = try Request(json: requestJSON)
            let resp = try Silo.shared.lockResponseFor(request: request, session: session, signatureAllowed: signatureAllowed)
            try Silo.shared.send(session: session, response: resp, completionHandler: completionHandler)
            
        } catch (let e) {
            log("handle error \(e)", .error)
            completionHandler()
            return
        }
        

    }
    
    //MARK: Links
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        guard let link = Link(url: url) else {
            log("invalid kr url: \(url)", .error)
            return false
        }
        
        self.pendingLink = link
        NotificationCenter.default.post(name: Link.notificationName, object: link, userInfo: nil)
        return true
    }
    
    //MARK: Update Checking in the Background
    
    func checkForAppUpdateIfNeededBackground() {
        Updater.checkForUpdateIfNeeded { (version) in
            guard let newVersion = version else {
                log("no new version found")
                return
            }
            
            let notification = UILocalNotification()
            notification.alertBody = "A new version of Kryptonite (v\(newVersion.string)) is now available!"
            notification.soundName = UILocalNotificationDefaultSoundName
            UIApplication.shared.presentLocalNotificationNow(notification)

        }

    }
   
    //MARK: App Lifecycle
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
        LogManager.shared.saveContext()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        Analytics.appClose()
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        application.applicationIconBadgeNumber = 1
        application.applicationIconBadgeNumber = 0
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        Analytics.setUserAgent()
        Analytics.appOpen()
        pendingAuthorizationMutex.lock {
            if let (session, request) = Policy.pendingAuthorization {
                log("requesting pending authorization")
                Policy.requestUserAuthorization(session: session, request: request)
            }

        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        LogManager.shared.saveContext()
    }


}

