//
//  KRBaseController.swift
//  Krypton
//
//  Created by Alex Grinman on 9/26/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

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

class KRBaseController: UIViewController, KRBase {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    var connectivity:Connectivity?
    var linkListener:LinkListener?
    
    func run(syncOperation:@escaping (() throws ->Void), title:String, onSuccess:(()->Void)? = nil, onError:(()->Void)? = nil) {
        self.run(viewController: self, syncOperation: syncOperation, title: title, onSuccess: onSuccess, onError: onError)
    }

    //MARK: Policy
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Current.viewController = self
        if shouldPostAnalytics() {
            Analytics.postControllerView(clazz: String(describing: type(of: self)))
        }
        
        checkIfPushEnabled(viewController: self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkForUpdatesIfNeeded(viewController: self)
        connectivity = Connectivity(presenter: self)
        linkListener = LinkListener({ (link) in
            self.onListen(viewController: self, link: link)
        })
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
        
        checkIfPushEnabled(viewController: self)
    }
    
    func run(syncOperation:@escaping (() throws ->Void), title:String, onSuccess:(()->Void)? = nil, onError:(()->Void)? = nil) {
        self.run(viewController: self, syncOperation: syncOperation, title: title, onSuccess: onSuccess, onError: onError)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkForUpdatesIfNeeded(viewController: self)
        connectivity = Connectivity(presenter: self)
        linkListener = LinkListener({ (link) in
            self.onListen(viewController: self, link: link)
        })
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

extension UINavigationController: KRBase {
    func approveControllerDismissed(allowed: Bool) {
        if let root = self.viewControllers.first {
            self.defaultApproveControllerDismissed(viewController: root, allowed: allowed)
        }
    }
}

extension KRBase {
        
    func run(viewController:UIViewController, syncOperation:@escaping (() throws ->Void), title:String, onSuccess:(()->Void)? = nil, onError:(()->Void)? = nil) {
        let loading = LoadingController.present(from: viewController)
        dispatchAsync {
            do {
                try syncOperation()
                loading?.showSuccess(hideAfter: 0.75, then: onSuccess)
            } catch {
                loading?.showError(hideAfter: 0.5, title: "\(title) Error", error: "\(error)", then: onError)
            }
        }
    }

    
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

    
    //MARK: Check For push notifications
    func checkIfPushEnabled(viewController:UIViewController) {
        if Platform.isSimulator {
            return
        }
        
        
        // check app is registered for push notifications
        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in
            if settings.authorizationStatus == .notDetermined && ((try? KeyManager.hasKey()) == .some(true)) && Onboarding.isActive == false  {
                dispatchMain {
                    (UIApplication.shared.delegate as? AppDelegate)?.registerPushNotifications()
                }
                return
            }
            
            // dont bother
            if UserDefaults.standard.bool(forKey: "push_dnd") {
                return
            }
            
            if settings.alertSetting == .disabled || settings.authorizationStatus == .denied {
                viewController.showSettings(with: "Push Notifications",
                                  message: "Enable push notifications to receive SSH Login and Git Commit/Tag Signing requests when your phone is locked or the app is in the background. Tap \"Settings\" to continue.",
                                  dnd: "push_dnd")
            }
        })
    }

    //MARK: Updates
    func checkForUpdatesIfNeeded(viewController:UIViewController) {
        // app updates
        Updater.checkForUpdateIfNeeded { (version) in
            guard let newVersion = version else {
                return
            }
            
            let alertController = UIAlertController(title: "New Version",
                                                    message: "\(Properties.appName) v\(newVersion.string) is now available! Tap \"Download\" to go to the App Store to get the latest and greatest features.",
                                                    preferredStyle: .alert)
            
            let downloadAction = UIAlertAction(title: "Download", style: .default) { (alertAction) in
                
                if let appStoreURL = URL(string: Properties.appStoreURL) {
                    UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
                }
            }
            alertController.addAction(downloadAction)
            
            let cancelAction = UIAlertAction(title: "Later", style: .cancel, handler: nil)
            alertController.addAction(cancelAction)
            
            viewController.present(alertController, animated: true, completion: nil)
        }
        
        // team updates
        if case .some(let hasTeam) = try? IdentityManager.hasTeam(),
                hasTeam,
                TeamUpdater.shouldCheckTimed()
        {
            dispatchAsync {
                TeamUpdater.checkForUpdate { result in
                    log("did update team: \(result)")
                }
            }
        }
    }
    
    //MARK: React to links
    func onListen(viewController:UIViewController, link:Link) {
        switch link.type {
        case .app:
            self.handleJoinInviteLink(viewController: viewController, link: link)
        case .u2f, .u2fGoogle:
            self.handleU2F(viewController: viewController, link: link)
        default:
            log("unexpected link: \(link)", .error)
        }

    }
    
    func handleU2F(viewController:UIViewController, link:Link) {
        log("Got link: \(link.url.absoluteString)")
        
        guard   let data = link.properties["data"]?.removingPercentEncoding,
                let returnURL = link.properties["returnUrl"]?.removingPercentEncoding
        else {
            viewController.showWarning(title: "Invalid Request", body: "This request is using an invalid format. Please send an email to support@krypt.co.")
            return
        }
        
        do {
            let localU2FRequest = try LocalU2FRequest(jsonString: data)
            
            let approvalRequest = LocalU2FApproval(request: localU2FRequest,
                                                   trustedFacets: [],
                                                   returnURL: returnURL)
            
            viewController.requestLocalU2FAuthorization(localU2FApprovalRequest: approvalRequest)

        } catch LocalU2FRequest.Errors.noKnownKeyHandle {
            viewController.showWarning(title: "No Krypton Key on this Account", body: "This account does not have a Krypton key registered.")
        } catch {
            viewController.showWarning(title: "Error", body: "This request could not be handled: \(error). Please send an email to support@krypt.co.")
        }
    
        
    }
    
    func handleJoinInviteLink(viewController:UIViewController, link: Link) {
        guard case .joinTeam = link.command.host
            else {
                log("invalid link type presented: \(link.url)")
                return
        }
        
        do {
            if let team = try IdentityManager.getTeamIdentity()?.dataManager.withTransaction { return try $0.fetchTeam() } {
                viewController.showWarning(title: "Already on team \(team.info.name)", body: "\(Properties.appName) only supports being on one team. Multi-team support is coming soon!")
                return
            }
            
        } catch {
            viewController.showWarning(title: "Error", body: "Couldn't get team information. Error: \(error).")
            return
        }
        
        var teamInvite:SigChain.JoinTeamInvite
        do {
            teamInvite = try SigChain.JoinTeamInvite(path: link.path)
        } catch {
            viewController.showWarning(title: "Error", body: "Invalid team invitation encoding.")
            return
        }
        
        let loading = LoadingController.present(from: viewController)
        
        TeamService.fetchFullTeamInvite(for: teamInvite, { (result) in
            switch result {
            case .error(let e):
                loading?.showError(hideAfter: 0.5, title: "Error", error: "\(e)")
                
            case .result(let invite):
                loading?.showSuccess(hideAfter: 0.75, then: {
                    guard let teamLoadController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamLoadController") as? TeamLoadController
                        else {
                            log("unknown team invitiation controller")
                            return
                    }
                    
                    teamLoadController.modalTransitionStyle = UIModalTransitionStyle.coverVertical
                    teamLoadController.modalPresentationStyle = UIModalPresentationStyle.overFullScreen
                    
                    teamLoadController.joinType = .indirectInvite(invite)
                    
                    dispatchMain {
                        viewController.present(teamLoadController, animated: true, completion: nil)
                    }
                })
            }
        })

    }

   
}
