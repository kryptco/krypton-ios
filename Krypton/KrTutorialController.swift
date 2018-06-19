//
//  PairedUploadController.swift
//  Krypton
//
//  Created by Alex Grinman on 9/27/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class KrTutorialController:KRBaseController {
    
    
    @IBOutlet weak var commandLabel:UILabel!
    @IBOutlet weak var commandView:UIView!

    @IBOutlet weak var githubLabel:UILabel!
    @IBOutlet weak var githubCommandView:UIView!

    @IBOutlet weak var codesignLabel:UILabel!
    @IBOutlet weak var codesignCommandView:UIView!

    @IBOutlet weak var skipButton:UIButton!

    var session:Session?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        for v in [commandView, githubCommandView] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.175
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }
        
        githubLabel.alpha = 0
        githubCommandView.alpha = 0
        
        codesignLabel.alpha = 0
        codesignCommandView.alpha = 0

        Onboarding.isActive = false
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        
        
        return true
    }
    
    @IBAction func skipTapped() {
        self.navigationController?.dismiss(animated: true, completion: {
            MainController.current?.didDismissOnboarding()
        })
    }
    
    override func approveControllerDismissed(allowed: Bool) {
        super.approveControllerDismissed(allowed: allowed)
        
        UIView.animate(withDuration: 0.5, animations: {
            self.commandLabel.alpha = 0.5
            self.commandView.alpha = 0.5
            
            self.githubLabel.alpha = 1
            self.githubCommandView.alpha = 1
            

            self.skipButton.alpha = 1.0
            self.skipButton.setTitle("Done", for: UIControlState.normal)
            self.skipButton.setTitleColor(UIColor.app, for: UIControlState.normal)

        }, completion: {(_) -> Void in
            
            dispatchAfter(delay: 1.0, task: {
                UIView.animate(withDuration: 0.5, animations: {
                    self.codesignLabel.alpha = 1
                    self.codesignCommandView.alpha = 1
                })
            })

        })
    }
    
    

}
