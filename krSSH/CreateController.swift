//
//  CreateController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 11/26/15.
//  Copyright © 2015 KryptCo. All rights reserved.
//

import Foundation

class CreateController: UIViewController {

    @IBOutlet weak var createButton: UIButton!
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Welcome!"
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor.app
        
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]

        
        self.createButton.setBorder(color: UIColor.app, cornerRadius: 8.0, borderWidth: 1.0)
    }
    
    
    @IBAction func createTapped(sender: AnyObject) {
        
        // Create a new identity identifier
        do {
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.exportSecp()
            
            log("Generated public key: \(pk)")
            
            self.performSegue(withIdentifier: "showSetup", sender: nil)
            
        } catch (let e) {
            self.showWarning(title: "Crypto Error", body: "\(e)")
        }
        
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

    }
    
    

}
