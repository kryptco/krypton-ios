//
//  ViewController.swift
//  krSSH
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo Inc. All rights reserved.
//

import UIKit


class MainController: UITabBarController, UITabBarControllerDelegate {

    var blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.light))

    
    lazy var aboutButton:UIBarButtonItem = {
        return UIBarButtonItem(title: "i", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MainController.aboutTapped))
    }()
    
    lazy var helpButton:UIBarButtonItem = {
        return UIBarButtonItem(title: "?", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MainController.helpTapped))
    }()

    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.setKrLogo()
        
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor.app
        
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        
        self.tabBar.tintColor = UIColor.app
        self.delegate = self
        
        // add a blur view
        view.addSubview(blurView)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MainController.didRegisterPush), name: NSNotification.Name(rawValue: "registered_push_notifications"), object: nil)
        
        self.navigationItem.leftBarButtonItem = aboutButton
        self.navigationItem.rightBarButtonItem = helpButton
        
//        log("\(LogManager.shared.all.count)")
//        let _ = KeyManager.destroyKeyPair()
//        SessionManager.shared.destory()
//        PeerManager.shared.destory()
    }
    
    dynamic func didRegisterPush(note:Notification?) {
        guard let token = note?.object as? String else {
           showPushErrorAlert()
            return
        }
        
        
        API().updateSNS(token: token) { (endpoint, err) in
            guard let arn = endpoint else {
                log("AWS SNS error: \(err)", .error)
                dispatchMain { self.showPushErrorAlert() }
                return
            }
            
            let res = KeychainStorage().set(key: KR_ENDPOINT_ARN_KEY, value: arn)
            if !res { log("Could not save push ARN", .error) }
        }

    }
    
    func showPushErrorAlert() {
        if TARGET_IPHONE_SIMULATOR == 1 {
            return
        }

        let alertController = UIAlertController(title: "Push Notifications",
                                                message: "Push notifications are not enabled. Please enable push notifications to enable SSH login when the app is in the background. Tap `Settings` to continue.",
                                                preferredStyle: .alert)
        
        let settingsAction = UIAlertAction(title: "Settings", style: .default) { (alertAction) in
            
            if let appSettings = URL(string: UIApplicationOpenSettingsURLString) {
                UIApplication.shared.openURL(appSettings)
            }
        }
        alertController.addAction(settingsAction)
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        blurView.frame = view.frame
        self.blurView.isHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // temp delete
        
        
        guard KeyManager.hasKey() else {
            
            if let createNav = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "CreateNavigation") as? UINavigationController
            {
                self.present(createNav, animated: true, completion: nil)
            }
            
            return
        }
        
        do {
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.exportSecp()
            
            log("started with: \(pk)")
            
            UIView.animate(withDuration: 0.2, animations: { 
                self.blurView.isHidden = true
            })
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "load_new_me"), object: nil)

        } catch (let e) {
            log("\(e)", LogType.error)
            showWarning(title: "Fatal Error", body: "\(e)")
            return
        }
        
        //(self.viewControllers?.first as? MeController)?.updateCurrentUser()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    //MARK: Nav Bar Buttons
    
    dynamic func aboutTapped() {
        
    }
    
    dynamic func helpTapped() {
        
    }

}
