//
//  ViewController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 8/26/16.
//  Copyright © 2016 KryptCo, Inc. Inc. All rights reserved.
//

import UIKit

class MainController: UITabBarController, UITabBarControllerDelegate {

    var blurView = UIVisualEffectView(effect: UIBlurEffect(style: UIBlurEffectStyle.light))
    
    lazy var aboutButton:UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(named: "gear"), style: UIBarButtonItemStyle.plain, target: self, action: #selector(MainController.aboutTapped))
    }() 
    
    lazy var helpButton:UIBarButtonItem = {
        return UIBarButtonItem(title: "Help", style: UIBarButtonItemStyle.plain, target: self, action: #selector(MainController.helpTapped))
    }()
    
    enum TabsCount:Int {
        case noTeam = 3
        case hasTeam = 4
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.setKrLogo()
                
        self.tabBar.tintColor = UIColor.app
        self.delegate = self
        
        // add a blur view
        view.addSubview(blurView)
                
        self.navigationItem.leftBarButtonItem = aboutButton
        self.navigationItem.rightBarButtonItem = helpButton
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        blurView.frame = view.frame

        if !KeyManager.hasKey() {
            self.blurView.isHidden = false
        }
        
        // set the right 4th tab if needed
        createTeamTabIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard KeyManager.hasKey() else {
            self.performSegue(withIdentifier: "showOnboardGenerate", sender: nil)
            return
        }
        
        guard  let _ = try? KeyManager.sharedInstance().getMe()
        else {
            self.performSegue(withIdentifier: "showOnboardEmail", sender: nil)
            return
        }
        
        guard Onboarding.isActive == false else {
            self.performSegue(withIdentifier: "showOnboardFirstPair", sender: nil)
            return
        }
        
        UIView.animate(withDuration: 0.2, animations: {
            self.blurView.isHidden = true
        })
        
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: "load_new_me"), object: nil)

        
        // Check old version sessions
        let (hasOld, sessionNames) = SessionManager.hasOldSessions()
        if hasOld {
            self.performSegue(withIdentifier: "showRePairWarning", sender: sessionNames)
            return
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    @IBAction func dismissOnboarding(segue: UIStoryboardSegue) {
        Onboarding.isActive = false
    }
    

    @IBAction func dismissHelpAndGoToPair(segue: UIStoryboardSegue) {
        self.selectedIndex = 1
    }
    
    
    var shouldSwitchToTeams:Bool = false
    @IBAction func dismissJoinTeam(segue: UIStoryboardSegue) {
        if self.tabBar.items?.count == TabsCount.hasTeam.rawValue {
            self.selectedIndex = 3
        } else {
            shouldSwitchToTeams = true
        }
    }

    
    //MARK: Nav Bar Buttons
    
    @objc dynamic func aboutTapped() {
        self.performSegue(withIdentifier: "showAbout", sender: nil)
    }
    
    @objc dynamic func helpTapped() {
        self.performSegue(withIdentifier: "showInstall", sender: nil)
    }
    
    //MARK: Teams tab
    
    func createTeamTabIfNeeded() {
        
        // load the identients
        var identities:[Identity]
        do {
            identities = try IdentityManager.shared.list()
            guard !identities.isEmpty else {
                return
            }
        } catch {
            log("error loading identites: \(error)", .error)
            return
        }

        
        // already have 4th team tab
        if let viewControllers = self.viewControllers, viewControllers.count == TabsCount.hasTeam.rawValue {
            switch (identities.count, viewControllers[3]) {
                
            // no more teams, remove the 4th tab
            case (0, _):
                self.setViewControllers([UIViewController](viewControllers[0 ..< 3]), animated: true)
                
                if let items = self.tabBar.items, items.count == TabsCount.hasTeam.rawValue {
                    self.tabBar.setItems([UITabBarItem](items[0 ..< 3]), animated: true)
                }
                
                self.selectedIndex = 0
                return
            
            // only one team now, remove the 4th tab to change to team detail controller
            case let (c, v) where c == 1 && v is TeamListController:
                self.setViewControllers([UIViewController](viewControllers[0 ..< 3]), animated: true)

            // more than one team now, remove the 4th tab to change to team list controller
            case let (c, v) where c > 1 && v is TeamDetailController:
                self.setViewControllers([UIViewController](viewControllers[0 ..< 3]), animated: true)
                
            // the tab is set correctly, return
            default:
                return
            }
        }
        
        var controller:UIViewController
        var tabBarItem:UITabBarItem
        
        if identities.count == 1 {
            let detailController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamDetailController") as! TeamDetailController
            detailController.identity = identities[0]
            controller = detailController
            tabBarItem = UITabBarItem(title: identities[0].team.name, image: #imageLiteral(resourceName: "teams"), selectedImage: #imageLiteral(resourceName: "teams_selected"))
            
        } else if identities.count > 1 {
            controller = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamListController")
            tabBarItem = UITabBarItem(title: "Teams", image: #imageLiteral(resourceName: "teams"), selectedImage: #imageLiteral(resourceName: "teams_selected"))

        } else { //empty
            return
        }
        
        self.setViewControllers((self.viewControllers ?? []) + [controller], animated: true)
        controller.tabBarItem = tabBarItem
        
        if shouldSwitchToTeams {
            self.selectedIndex = 3
            shouldSwitchToTeams = false
        }
    }
    
    //MARK: Prepare for segue
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if  let rePairWarningController = segue.destination as? RePairWarningController,
            let sessionNames = sender as? [String]
        {
            rePairWarningController.names = sessionNames
        }
    }

}
