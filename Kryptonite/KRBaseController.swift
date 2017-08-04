//
//  KRBaseController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/26/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class Current {
    private static var mutex = Mutex()
    static var _viewController:UIViewController?
    static var viewController:UIViewController? {
        get {
            var controller:UIViewController?
            mutex.lock {
                controller = _viewController
            }
            
            return controller
        }
        
        set(c) {
            mutex.lock {
                _viewController = c
            }
            
        }
    }
}

protocol KRBase {
    func approveControllerDismissed(allowed:Bool)
}

extension KRBase {
    func defaultApproveControllerDismissed(viewController:UIViewController, allowed:Bool) {
        let result = allowed ? "allowed" : "rejected"
        log("approve modal finished with result: \(result)")
        
        // if rejected, reject all pending
        guard allowed else {
            Policy.rejectAllPendingIfNeeded()
            return
        }
        
        // send and remove pending that are already allowed
        Policy.sendAllowedPendingIfNeeded()
        
        // move on to next pending if necessary
        if let pending = Policy.lastPendingAuthorization {
            log("requesting pending authorization")
            viewController.requestUserAuthorization(session: pending.session, request: pending.request)
        }
    }
}

class KRBaseController: UIViewController, KRBase {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    var connectivity:Connectivity?
    var linkListener:LinkListener?
    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Current.viewController = self
        if shouldPostAnalytics() {
            Analytics.postControllerView(clazz: String(describing: type(of: self)))
        }
        
        checkIfPushEnabled()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkForUpdatesIfNeeded()
        connectivity = Connectivity(presenter: self)
        linkListener = LinkListener(self.onListen)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        connectivity = nil
        linkListener = nil
    }

    func shouldPostAnalytics() -> Bool {
        return true
    }
    
    func approveControllerDismissed(allowed:Bool) {
        self.defaultApproveControllerDismissed(viewController: self, allowed: allowed)
    }
}



class KRBaseTableController: UITableViewController, KRBase {
    
    var connectivity:Connectivity?
    var linkListener:LinkListener?

    
    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Current.viewController = self

        if shouldPostAnalytics() {
            Analytics.postControllerView(clazz: String(describing: type(of: self)))
        }
        
        checkIfPushEnabled()
    }
    

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkForUpdatesIfNeeded()
        connectivity = Connectivity(presenter: self)
        linkListener = LinkListener(self.onListen)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        connectivity = nil
        linkListener = nil
    }

    func shouldPostAnalytics() -> Bool {
        return true
    }

    func approveControllerDismissed(allowed:Bool) {
        self.defaultApproveControllerDismissed(viewController: self, allowed: allowed)
    }
}

extension UIViewController {
    
    //MARK: Check For push notifications
    func checkIfPushEnabled() {
        if Platform.isSimulator {
            return
        }

        // check app is registered for push notifications
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
        }
        else if  let settings = UIApplication.shared.currentUserNotificationSettings,
            settings.types.contains(.alert) == false
        {
            self.showSettings(with: "Please Enable Push Notifications", message: "If you enable push notifications you will be able to receive SSH login requests when your phone is locked or the app is not open. Tap \"Settings\" to continue.")
        }
    }

    //MARK: Updates
    func checkForUpdatesIfNeeded() {
        Updater.checkForUpdateIfNeeded { (version) in
            guard let newVersion = version else {
                return
            }
            
            let alertController = UIAlertController(title: "New Version",
                                                    message: "Kryptonite v\(newVersion.string) is now available! Tap \"Download\" to go to the App Store to get the latest and greatest features.",
                                                    preferredStyle: .alert)
            
            let downloadAction = UIAlertAction(title: "Download", style: .default) { (alertAction) in
                
                if let appStoreURL = URL(string: Properties.appStoreURL) {
                    UIApplication.shared.openURL(appStoreURL)
                }
            }
            alertController.addAction(downloadAction)
            
            let cancelAction = UIAlertAction(title: "Later", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    
    //MARK: React to links
    func onListen(link:Link) {
        guard link.type == .kr else {
            log("invalid link type presented: \(link.type)")
            return
        }
        
        
        switch link.command {
        case .joinTeam:
            
            guard   link.path.count == 2
            else {
                self.showWarning(title: "Error", body: "Invalid team invitation.")
                return
            }
            
            var teamInvite:TeamInvite
            do {
                let teamPublicKey = try SodiumPublicKey(link.path[0].fromBase64())
                let seed = try link.path[1].fromBase64()
                teamInvite = TeamInvite(teamPublicKey: teamPublicKey, seed: seed)
            } catch {
                self.showWarning(title: "Error", body: "Invalid team invitation encoding.")
                return
            }
            

            guard let teamLoadController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamLoadController") as? TeamLoadController
            else {
                log("unknown team invitiation controller")
                return
            }
            
            teamLoadController.invite = teamInvite
            
            dispatchMain {
                self.present(teamLoadController, animated: true, completion: nil)
            }
            
        }
    }

   
}
