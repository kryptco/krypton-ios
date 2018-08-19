//
//  U2FRequestController.swift
//  Krypton
//
//  Created by Alex Grinman on 5/3/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class U2FRequestController:UIViewController {
    
    @IBOutlet weak var action:UILabel!
    @IBOutlet weak var suffix:UILabel!
    @IBOutlet weak var logo:UIImageView!
    @IBOutlet weak var display:UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
    }
    
    func set(register:U2FRegisterRequest) {
        action.text = "Register"
        suffix.text = "with"
        setSiteLogoAndDisplay(app: register.appID)
    }
    
    func set(authenticate:U2FAuthenticateRequest) {
        set(authenticateTo: authenticate.appID)
    }
    
    func set(authenticateTo appId:U2FAppID) {
        action.text = "Login"
        suffix.text = "to"
        setSiteLogoAndDisplay(app: appId)
    }

    func setSiteLogoAndDisplay(app: U2FAppID) {
        let known = KnownU2FApplication(for: app)
        
        logo.image = known?.logo ?? #imageLiteral(resourceName: "default")
        display.text = known?.displayName ?? app
        
        display.textColor = known?.branding?.text ?? UIColor.app
    }
}

extension KnownU2FApplication {
    var logo:UIImage {
        switch self {
        case .google:
            return #imageLiteral(resourceName: "google")
        case .dropbox:
            return #imageLiteral(resourceName: "dropbox")
        case .facebook:
            return #imageLiteral(resourceName: "facebook")
        case .twitter:
            return #imageLiteral(resourceName: "twitter")
        case .github:
            return #imageLiteral(resourceName: "github")
        case .stripe:
            return #imageLiteral(resourceName: "stripe")
        case .gitlab:
            return #imageLiteral(resourceName: "gitlab")
        case .duoDemo:
            return #imageLiteral(resourceName: "duo")
        case .keeper:
            return #imageLiteral(resourceName: "keeper")
        case .fedora:
            return #imageLiteral(resourceName: "fedora")
        case .bitbucket:
            return #imageLiteral(resourceName: "bitbucket")
        case .sentry:
            return #imageLiteral(resourceName: "sentry")
        default:
            return #imageLiteral(resourceName: "default")
        }
    }
}
