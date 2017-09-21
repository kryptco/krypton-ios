//
//  HelpController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 10/4/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation
import UIKit

class HelpInstallController:KRBaseController {

    @IBOutlet weak var installLabel:UILabel!
    @IBOutlet weak var brewButton:UIButton!
    @IBOutlet weak var brewLine:UIView!
    
    @IBOutlet weak var curlButton:UIButton!
    @IBOutlet weak var curlLine:UIView!
    
    @IBOutlet weak var npmButton:UIButton!
    @IBOutlet weak var npmLine:UIView!

    @IBOutlet weak var moreButton:UIButton!
    @IBOutlet weak var moreLine:UIView!

    @IBOutlet weak var commandView:UIView!

    var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        commandView.layer.shadowColor = UIColor.black.cgColor
        commandView.layer.shadowOffset = CGSize(width: 0, height: 0)
        commandView.layer.shadowOpacity = 0.175
        commandView.layer.shadowRadius = 3
        commandView.layer.masksToBounds = false
        
        setCurlState()
    }
  
    //MARK: Install Instructions
    
    @IBAction func brewTapped() {
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        brewLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.brew.command
        
        Analytics.postEvent(category: "help_install", action: "brew")
    }
    
    @IBAction func npmTapped() {
        disableAllInstallButtons()
        
        npmButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        npmLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.npm.command
        
        Analytics.postEvent(category: "help_install", action: "npm")
    }
    
    func setCurlState() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        curlLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.curl.command
    }
    
    @IBAction func curlTapped() {
        setCurlState()
        Analytics.postEvent(category: "help_install", action: "curl")
    }
    
    @IBAction func moreTapped() {
        disableAllInstallButtons()
        
        moreButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        moreLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.more.command
        
        Analytics.postEvent(category: "help_install", action: "more")
    }

    
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        npmButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        moreButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)

        brewLine.backgroundColor = UIColor.clear
        curlLine.backgroundColor = UIColor.clear
        npmLine.backgroundColor = UIColor.clear
        moreLine.backgroundColor = UIColor.clear
    }
    
    @IBAction func goToHelpInstall(segue: UIStoryboardSegue) {
    }


}

