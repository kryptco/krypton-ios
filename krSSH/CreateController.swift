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
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        // enable by default
        Policy.needsUserApproval = true
        
        createButton.layer.shadowColor = UIColor.black.cgColor
        createButton.layer.shadowOffset = CGSize(width: 0, height: 0)
        createButton.layer.shadowOpacity = 0.175
        createButton.layer.shadowRadius = 3
        createButton.layer.masksToBounds = false
        
        Analytics.postEvent(category: "onboard", action: "start")
    }
    
    
    @IBAction func createTapped(sender: AnyObject) {
        Analytics.postEvent(category: "onboard", action: "generate tapped")
        performSegue(withIdentifier: "showGenerate", sender: nil)
        
    }
    
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {

    }
    
    

}
