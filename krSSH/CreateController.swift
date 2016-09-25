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
    
    @IBOutlet weak var fpIconView:UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.barTintColor = UIColor.app
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.white]
        
        self.navigationItem.setKrLogo()
        
        fpIconView.layer.minificationFilter = kCAFilterTrilinear
        fpIconView.layer.shouldRasterize = true
        fpIconView.layer.allowsEdgeAntialiasing = true
        fpIconView.layer.rasterizationScale = UIScreen.main.scale

        
        self.createButton.setBorder(color: UIColor.app, cornerRadius: 10.0, borderWidth: 2.0)
    }
    
    
    @IBAction func createTapped(sender: AnyObject) {
        
        // Create a new identity identifier
        let didDestroy = KeyManager.destroyKeyPair()
        log("destroyed keypair: \(didDestroy)")
        
        do {
            try KeyManager.generateKeyPair()
            
            let kp = try KeyManager.sharedInstance().keyPair
            let pk = try kp.publicKey.export().toBase64()
            
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
