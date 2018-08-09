//
//  DeveloperStartController.swift
//  Krypton
//
//  Created by Alex Grinman on 8/8/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation

class DeveloperStartController:UIViewController {
    
    @IBOutlet weak var keyTypeButton:UIButton!
    @IBOutlet weak var generateButton:UIButton!

    var keyType:KeyType = .RSA
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        generateButton.setBoxShadow()
        Analytics.postEvent(category: "developer-onboard", action: "start")

        if (try? KeyManager.hasKey()) == .some(true) {
            let install = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "InstallKrController") as! InstallKrController
            self.navigationController?.pushViewController(install, animated: true)
        }
        
        keyTypeButton.setTitle(keyType.prettyDescription, for: .normal)
    }

    @IBAction func cycleKeyType() {
        switch keyType {
        case .RSA:
            keyType = .Ed25519
        case .Ed25519:
            keyType = .nistP256
        case .nistP256:
            keyType = .RSA
        }
        
        keyTypeButton.setTitle(keyType.prettyDescription, for: .normal)
    }
    
    @IBAction func generateTapped() {
        let gen = Resources.Storyboard.Main.instantiateViewController(withIdentifier: "GenerateController") as! GenerateController
        gen.keyType = self.keyType
        self.navigationController?.pushViewController(gen, animated: true)
    }
    
    @IBAction func cancelTapped() {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

}

extension KeyType {
    var prettyDescription:String {
        switch self {
        case .Ed25519, .RSA:
            return self.description
        case .nistP256:
            return "\(self.description) SecureEnclave"
        }
    }
}
