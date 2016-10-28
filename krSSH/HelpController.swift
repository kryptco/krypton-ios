//
//  HelpController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/4/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class HelpController:KRBaseController {
    

    @IBAction func goToHelpStart(segue: UIStoryboardSegue) {
    }
    

}

class HelpInstallController:KRBaseController {

    @IBOutlet weak var installLabel:UILabel!
    @IBOutlet weak var brewButton:UIButton!
    @IBOutlet weak var brewLine:UIView!
    
    @IBOutlet weak var curlButton:UIButton!
    @IBOutlet weak var curlLine:UIView!
    
    @IBOutlet weak var npmButton:UIButton!
    @IBOutlet weak var npmLine:UIView!

    @IBOutlet weak var commandView:UIView!

    @IBInspectable var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandView.layer.shadowColor = UIColor.black.cgColor
        commandView.layer.shadowOffset = CGSize(width: 0, height: 0)
        commandView.layer.shadowOpacity = 0.175
        commandView.layer.shadowRadius = 3
        commandView.layer.masksToBounds = false

        
        brewTapped()
    }
  
    //MARK: Install Instructions
    
    @IBAction func brewTapped() {
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        brewLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.brew.rawValue
    }
    
    @IBAction func npmTapped() {
        disableAllInstallButtons()
        
        npmButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        npmLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.npm.rawValue
        
        Analytics.postEvent(category: "install", action: "bpm")
    }
    
    @IBAction func curlTapped() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        curlLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.curl.rawValue
        
        Analytics.postEvent(category: "install", action: "curl")
    }
    
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        npmButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        
        brewLine.backgroundColor = UIColor.clear
        curlLine.backgroundColor = UIColor.clear
        npmLine.backgroundColor = UIColor.clear
        
    }
    
    @IBAction func goToHelpInstall(segue: UIStoryboardSegue) {
    }


}

class HelpAddPubKeyController:KRBaseController {}

