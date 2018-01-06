//
//  CreateController.swift
//  Krypton
//
//  Created by Alex Grinman on 11/26/15.
//  Copyright © 2015 KryptCo. All rights reserved.
//

import Foundation


class CreateController: UIViewController {

    @IBOutlet weak var createButton: UIButton!
    @IBOutlet weak var keyTypeButton: UIButton!

    var keyType = KeyType.RSA
    

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        createButton.layer.shadowOpacity = 0.175
        createButton.layer.shadowRadius = 3
        createButton.layer.masksToBounds = false
        
        keyTypeButton.setTitle(keyType.prettyPrint(), for: UIControlState.normal)
        
        Analytics.postEvent(category: "onboard", action: "start")
    }
    
    
    @IBAction func createTapped(sender: AnyObject) {
        Analytics.postEvent(category: "onboard", action: "generate tapped")
        performSegue(withIdentifier: "showGenerate", sender: nil)
        
    }
    
    @IBAction func switchKeyTypeTapped(sender: AnyObject) {
        switch keyType {
        case .nistP256:
            keyTypeButton.setTitle(KeyType.RSA.prettyPrint(), for: UIControlState.normal)
            keyType = .RSA
        case .Ed25519:
            keyTypeButton.setTitle(KeyType.nistP256.prettyPrint(), for: UIControlState.normal)
            keyType = .nistP256
        case .RSA:
            keyTypeButton.setTitle(KeyType.Ed25519.prettyPrint(), for: UIControlState.normal)
            keyType = .Ed25519
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let generateController = segue.destination as? GenerateController {
            generateController.keyType = self.keyType
        }

    }    

}


extension KeyType {
    func prettyPrint() -> String{
        switch self {
        case .Ed25519:
            return " Ed25519 "
        case .RSA:
            return " RSA "
        case .nistP256:
            return " NIST P-256 (Secure Enclave) "
        }

    }
}
