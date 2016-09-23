//
//  AboutController.swift
//  krSSH
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit

class AboutController: UIViewController {

    @IBOutlet weak var versionLabel:UILabel!
    @IBOutlet weak var approvalSwitch:UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()

        approvalSwitch.isOn = Policy.needsUserApproval
        
        if  let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
            let hash = Bundle.main.infoDictionary?["GitHash"] as? String
        {
            let hashShort = hash.substring(to: hash.index(hash.startIndex, offsetBy: min(6, hash.characters.count)))
            self.versionLabel.text = "v\(version).\(build) - \(hashShort)"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Policy.currentViewController = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func doneTapped() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction func userApprovalSettingChanged(sender:UISwitch) {
        Policy.needsUserApproval = sender.isOn
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
