//
//  FirstPairController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import UIKit

class FirstPairController:UIViewController, KRScanDelegate {
    
    enum InstallMethod:String {
        case brew = "brew install kryptco/tap/kr"
        case curl = "brew install kryptco/tap/kr"
        case apt = "brew install kryptco/tap/kr"
    }
    
    @IBOutlet weak var installLabel:UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanController = segue.destination as? KRScanController {
            scanController.delegate = self
        } else if
            let animationController = segue.destination as? PairingAnimationController,
            let session = sender as? Session
        {
            animationController.session = session
        }
    }
    
    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard   let value = data.data(using: String.Encoding.utf8),
            let json = (try? JSONSerialization.jsonObject(with: value, options: JSONSerialization.ReadingOptions.allowFragments)) as? [String:AnyObject]
            else {
                return false
        }
        
        
        if let pairing = try? Pairing(json: json) {
            
            do {
                let session = try Session(pairing: pairing)
                Silo.shared.add(session: session)
                self.performSegue(withIdentifier: "showPairingAnimation", sender: session)
            } catch (let e) {
                log("error scanning: \(e)", .error)
                return false
            }

            
            return true
        }
        
        
        return false
    }
}
