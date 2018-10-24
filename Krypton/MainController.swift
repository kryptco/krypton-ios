//
//  ViewController.swift
//  Krypton
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
    
    enum TabIndex:Int  {
        case securityKeys = 0
        case backupCodes = 1
        case pair = 2
        case devices = 3
        case developer = 4
        case teams = 5
        
        var index:Int { return rawValue }
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
        
        self.navigationController?.view.backgroundColor = UIColor.white
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        blurView.frame = view.frame
        self.blurView.isHidden = !(Onboarding.isActive || !Onboarding.hasStarted)
        updateTabsIfNeeded()
    }
    
    static var current:MainController? {
        let mainNav = UIApplication.shared.delegate?.window??.rootViewController as? UINavigationController
        return mainNav?.viewControllers.first as? MainController
    }
    
    func didDismissOnboarding() {
        Onboarding.isActive = false

        dispatchMain {
            self.blurView.isHidden = true
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard KeychainStorage().isInteractionAllowed() else {
            self.showWarning(title: "Keychain locked", body: "Please restart Krypton and wait a few seconds.")
            return
        }        

        // if we dont have key pair
        // and onboarding has never started
        // show onboarding
        if (try? KeyManager.hasKey()) != .some(true) {
            guard Onboarding.hasStarted else {
                self.performSegue(withIdentifier: "showOnboard", sender: nil)
                return
            }
        }
        
        // if onboarding is still active
        // show u2f pair instruction
        guard Onboarding.isActive == false else {
            self.performSegue(withIdentifier: "showInstallU2F", sender: nil)
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
        self.selectedIndex = TabIndex.pair.index
    }
    
    
    var shouldSwitchToTeams:Bool = false
    @IBAction func dismissJoinTeam(segue: UIStoryboardSegue) {
        updateTabsIfNeeded()
        self.selectedIndex = TabIndex.teams.index
    }
    
    @IBAction func didDeleteTeam(segue: UIStoryboardSegue) {
        updateTabsIfNeeded()
        self.selectedIndex = TabIndex.securityKeys.index
    }

    
    //MARK: Nav Bar Buttons
    
    @objc dynamic func aboutTapped() {
        self.performSegue(withIdentifier: "showAbout", sender: nil)
    }
    
    @objc dynamic func helpTapped() {
        self.performSegue(withIdentifier: "showInstall", sender: nil)
    }
    
    //MARK: Updating tabs
    
    func updateTabsIfNeeded() {
        displayDeveloperModeTab(isVisible: DeveloperMode.isOn)
        updateTeamTabIfNeeded()
    }
    
    func displayDeveloperModeTab(isVisible: Bool) {
        guard isVisible else {
            self.setViewControllers([UIViewController](viewControllers?[0 ... TabIndex.devices.index] ?? []), animated: true)
            return
        }
        
        guard case .some(let tabCount) = self.viewControllers?.count, tabCount < TabIndex.developer.index + 1 else {
            return // already have the developer tab
        }
        
        let controller = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "MeController") as! MeController
        let tabBarItem = UITabBarItem(title: "Developer", image: #imageLiteral(resourceName: "developer-1"), selectedImage: #imageLiteral(resourceName: "developer-1"))
        
        let controllers = viewControllers?[0 ..< TabIndex.developer.index] ?? []
        self.setViewControllers([UIViewController](controllers + [controller]), animated: true)
        controller.tabBarItem = tabBarItem
    }
    
    func updateTeamTabIfNeeded(goToFirstPage:Bool = false) {
        guard DeveloperMode.shouldShowTeamsTab() else {
            if DeveloperMode.isOn {
                self.setViewControllers([UIViewController](viewControllers?[0 ... TabIndex.developer.index] ?? []), animated: true)
            } else {
                self.setViewControllers([UIViewController](viewControllers?[0 ... TabIndex.devices.index] ?? []), animated: true)
            }
            return
        }
        
        var teamIdentity:TeamIdentity?
        var team:Team?
        
        do {
            teamIdentity = try IdentityManager.getTeamIdentity()
        } catch {
            log("error loading team: \(error)", .error)
            teamIdentity = nil
        }
        
        do {
            team = try teamIdentity?.dataManager.withTransaction { return try $0.fetchTeam() }
        } catch {
            log("error loading team: \(error)", .error)
            team = nil
        }
        
        switch teamIdentity {
        case .some(let identity): // team detail controller
            switch team {
            case .some(let team):
                let controller = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamDetailController") as! TeamDetailController
                controller.identity = identity

                let tabBarItem = UITabBarItem(title: String(team.name.prefix(16)), image: #imageLiteral(resourceName: "teams"), selectedImage: #imageLiteral(resourceName: "teams_selected"))
                
                let controllers = viewControllers?[0 ..< TabIndex.teams.index] ?? []
                self.setViewControllers([UIViewController](controllers + [controller]), animated: true)
                controller.tabBarItem = tabBarItem
                
                if shouldSwitchToTeams {
                    self.selectedIndex = TabIndex.teams.index
                    shouldSwitchToTeams = false
                }

            case .none:
                // must re-bootstrap:
                let alertController:UIAlertController = UIAlertController(title: "Team Detected",
                                                                          message: "Would like to restore this team by re-bootstrapping all the team data? This may take a few seconds.",
                                                                          preferredStyle: .alert)
                
                
                
                
                alertController.addAction(UIAlertAction(title: "Yes, Restore", style: .default, handler: { (action:UIAlertAction) -> Void in
                    let loading = LoadingController.present(from: self)
                    
                    dispatchAsync {
                        do {
                            let result = try TeamService.shared().getVerifiedTeamUpdatesSync()
                            
                            switch result {
                            case .error(let e):
                                throw e
                                
                            case .result(let service):
                                do {
                                    try IdentityManager.commitTeamChanges(identity: service.teamIdentity)
                                } catch {
                                    loading?.showError(hideAfter: 0.5, title: "Error loading team data", error: "\(error)")
                                    return
                                }
                                
                                loading?.showSuccess(hideAfter: 0.75, then: {
                                    self.updateTeamTabIfNeeded()
                                })
                            }
                            
                        } catch {
                            loading?.showError(hideAfter: 0.5, title: "Error loading team data", error: "\(error)")
                        }
                    }

                }))
                
                alertController.addAction(UIAlertAction(title: "Delete the team", style: .destructive, handler: { (action:UIAlertAction) -> Void in
                    try? IdentityManager.removeTeamIdentity()
                }))

                alertController.addAction(UIAlertAction(title: "Ask me later", style: .cancel, handler: { (action:UIAlertAction) -> Void in
                    
                }))
                
                self.present(alertController, animated: true, completion: nil)
            }

            
        case .none: // marketing controller            
            let marketingController = Resources.Storyboard.Team.instantiateViewController(withIdentifier: "TeamsMarketingController") as! TeamsMarketingController
            let tabBarItem = UITabBarItem(title: "Teams", image: #imageLiteral(resourceName: "teams"), selectedImage: #imageLiteral(resourceName: "teams_selected"))
            
            let controllers = viewControllers?[0 ..< TabIndex.teams.index] ?? []
            self.setViewControllers([UIViewController](controllers + [marketingController]), animated: true)
            marketingController.tabBarItem = tabBarItem
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
