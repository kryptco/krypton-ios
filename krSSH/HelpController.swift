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
        
    @IBInspectable var inactiveUploadMethodColor:UIColor = UIColor.lightGray
    
    enum InstallMethod:String {
        case brew = "brew install kryptco/tap/kr"
        case curl = "curl https://krypt.co/kr | sh"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        brewTapped()
    }
  
    //MARK: Install Instructions
    
    @IBAction func brewTapped() {
        disableAllInstallButtons()
        
        brewButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        brewLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.brew.rawValue
    }
    
    @IBAction func curlTapped() {
        disableAllInstallButtons()
        
        curlButton.setTitleColor(UIColor.app, for: UIControlState.normal)
        curlLine.backgroundColor = UIColor.app
        installLabel.text = InstallMethod.curl.rawValue
    }
    
    func disableAllInstallButtons() {
        
        brewButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        curlButton.setTitleColor(inactiveUploadMethodColor, for: UIControlState.normal)
        
        brewLine.backgroundColor = UIColor.clear
        curlLine.backgroundColor = UIColor.clear
    }
    
    @IBAction func goToHelpInstall(segue: UIStoryboardSegue) {
    }


}

class HelpAddPubKeyController:KRBaseController {}

