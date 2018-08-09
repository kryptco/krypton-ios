//
//  CreateController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/26/15.
//  Copyright © 2015 KryptCo. All rights reserved.
//

import Foundation


class GetStartedController: UIViewController {

    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var firstMessage: UILabel!
    @IBOutlet weak var secondMessage: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Onboarding.hasStarted = true
        Onboarding.isActive = true
        createButton.setBoxShadow()
        Analytics.postEvent(category: "onboard", action: "start")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @IBAction func createTapped(sender: AnyObject) {
        Analytics.postEvent(category: "onboard", action: "generate tapped easy")
        
        // set me to the device name
        IdentityManager.setMe(email: UIDevice.current.name)
        
        let installController = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "InstallU2FController") as! InstallU2FController
        self.navigationController?.pushViewController(installController, animated: true)
    }
}
