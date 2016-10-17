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

    enum InstallMethod:String {
        case brew = "brew install kryptco/tap/kr"
        case curl = "curl https://krypt.co/kr | sh"
        case apt = "apt-get install kr"
        
    }
    
    @IBAction func brewTapped() {
        installLabel.text = InstallMethod.brew.rawValue
    }
    
    @IBAction func aptGetTapped() {
        installLabel.text = InstallMethod.apt.rawValue
    }
    
    @IBAction func curlTapped() {
        installLabel.text = InstallMethod.curl.rawValue
    }
    
    @IBAction func goToHelpInstall(segue: UIStoryboardSegue) {
    }


}

class HelpAddPubKeyController:KRBaseController {}

