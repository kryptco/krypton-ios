//
//  MeController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/10/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class MeController:UIViewController {
    @IBOutlet var identiconView:UIImageView!

    /*
 
     do {
     let publicKey = try KeyManager.sharedInstance().keyPair.publicKey.exportSecp()
     keyLabel.text = try publicKey.fingerprint().hexPretty
     tagLabel.text = try KeyManager.sharedInstance().getMe().email
     
     identiconView.image = IGSimpleIdenticon.from(publicKey, size: CGSize(width: 100, height: 100))
     
     } catch (let e) {
     log("error getting keypair: \(e)", LogType.error)
     showWarning(title: "Error loading keypair", body: "\(e)")
     }

 */
}
