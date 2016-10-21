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
    @IBOutlet weak var dontHaveLabel:UILabel!
    @IBOutlet weak var installMethodButton:UIButton!

    enum InstallMethod:String {
        case brew = "brew install kryptco/tap/kr"
        case curl = "curl https://krypt.co/kr | sh"
    }
    
    @IBAction func switchIntallMethodTapped() {
        
        guard let installMethodString = self.installLabel.text,
            let installMethod = InstallMethod(rawValue: installMethodString)
            else {
                return
        }
        
        switch installMethod {
        case .brew:
            self.installLabel.text = InstallMethod.curl.rawValue
            self.installMethodButton.setTitle("brew", for: UIControlState.normal)
            self.dontHaveLabel.text = "Install with brew instead?"
        case .curl:
            self.installLabel.text = InstallMethod.brew.rawValue
            self.installMethodButton.setTitle("curl", for: UIControlState.normal)
            self.dontHaveLabel.text = "Don't have brew?"
            
        }
        
    }
    
    @IBAction func goToHelpInstall(segue: UIStoryboardSegue) {
    }


}

class HelpAddPubKeyController:KRBaseController {}

