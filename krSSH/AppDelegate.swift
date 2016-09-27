//
//  AppDelegate.swift
//  krSSH
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var pendingLink:Link?
    
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey : Any]? = nil) -> Bool {
                
        Resources.makeAppearences()
        
        if !API.provision(accessKey: "AKIAJMZJ3X6MHMXRF7QQ", secretKey: "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") {
            log("API provision failed.", LogType.error)
        }
        
        AWSLogger.default().logLevel = .none
        Silo.shared.add(sessions: SessionManager.shared.all)
        Silo.shared.startPolling()
        
        registerPushNotifications()
        
        // check for link
        if  let url = launchOptions?[UIApplicationLaunchOptionsKey.url] as? URL,
            let link = Link(url: url)
        {
            pendingLink = link
        }
        
        //TODO: check for remote notification
        
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
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "registered_push_notifications"), object: token)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        
        log("Push registration failed!", .warning)
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "registered_push_notifications"), object: nil)

    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        
        log("got background notification")
        
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
            try Silo.shared.handle(request: req, session: session, completionHandler: { completionHandler(.newData) })

        } catch let e {
            log("error creating or sending response: \(e)")
            completionHandler(.failed)
        }
    

    }
    
    
    //MARK: Tap local notification
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        
        // if approval notification
        if
            let sessionID = notification.userInfo?["session_id"] as? String,
            let session = SessionManager.shared.get(id: sessionID),
            let requestJSON = notification.userInfo?["request"] as? JSON,
            let request = try? Request(json: requestJSON)
            
        {
            Policy.requestUserAuthorization(session: session, request: request)
        }
        
        
    }
    
    //MARK: Allow/Reject
    
    func application(_ application: UIApplication,
                     handleActionWithIdentifier identifier: String?,
                     for notification: UILocalNotification,
                     completionHandler: @escaping () -> Void ){
        
        guard identifier == Policy.approveAction.identifier else {
            log("user rejected", .warning)
            return
        }
        
        guard   let sessionID = notification.userInfo?["session_id"] as? String,
            let session = SessionManager.shared.get(id: sessionID),
            let requestJSON = notification.userInfo?["request"] as? JSON
            else {

                log("invalid notification", .error)
                return
        }
        
        do {
            let request = try Request(json: requestJSON)
            let resp = try Silo.shared.lockResponseFor(request: request, session: session)
            try Silo.shared.send(session: session, response: resp, completionHandler: completionHandler)
            
        } catch (let e) {
            log("handle error \(e)", .error)
            completionHandler()
            return
        }
        
    }
    
    //MARK: Integrations OAuth
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        
        guard let appLink = AppLinkType(rawValue: url.scheme ?? "") else {
            log("invalid open url scheme", .error)
            return false
        }
        
        switch appLink {
        case AppLinkType.github:
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "finish_github_login"), object: url, userInfo: nil)
            return true
        case AppLinkType.file:
            guard   let pubKeyFile = try? String(contentsOf: url, encoding: String.Encoding.utf8),
                    let components = try? pubKeyFile.byRemovingComment(),
                    let pubKeyWire = try? components.0.toWire()
            else {
                log("invalid pubkey file at url: \(url)")
                return false
            }
            
            let peer = Peer(email: components.1, fingerprint: pubKeyWire.fingerprint(), publicKey: pubKeyWire)
            PeerManager.shared.add(peer: peer)
            
            return true
            
        case AppLinkType.kryptonite:
            guard let link = Link(url: url) else {
                log("invalid kr url: \(url)")
                return false
            }
            
            self.pendingLink = link
            NotificationCenter.default.post(name: link.command.notificationName, object: link, userInfo: nil)
            return true
            
        }
    }
    
   
    //MARK: App Lifecycle
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        LogManager.shared.saveContext()
    }


}

