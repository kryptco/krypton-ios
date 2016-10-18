//
//  AboutController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit
import LocalAuthentication
import MessageUI

class AboutController: KRBaseController, UINavigationControllerDelegate, MFMailComposeViewControllerDelegate {

    @IBOutlet weak var versionLabel:UILabel!
    @IBOutlet weak var approvalSwitch:UISwitch!
    @IBOutlet weak var timeRemainingLabel:UILabel!

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
        
        if let remaining = Policy.approvalTimeRemaining {
            timeRemainingLabel.text = "Authorized for \(remaining)"
        } else {
            timeRemainingLabel.text = ""
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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
        timeRemainingLabel.text = ""
    }
    
    
    @IBAction func trashTapped() {
        
        let sheet = UIAlertController(title: "Do you want to destroy your private and public key?", message: "Your private key will be gone forever and you will be asked to generate a new one. You will be unpaired from all devices.", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Delete key pair", style: UIAlertActionStyle.destructive, handler: { (action) in
            self.deleteKeyTapped()
        }))
        
        sheet.addAction(UIAlertAction(title: "Cancel", style: UIAlertActionStyle.cancel, handler: { (action) in
        }))
        
        present(sheet, animated: true, completion: nil)
        
    }
    
    
    func deleteKeyTapped() {
        
        authenticate { (yes) in
            guard yes else {
                return
            }
            
            let _ = KeyManager.destroyKeyPair()
            SessionManager.shared.destory()
            
            dispatchMain {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        let reason = "Authentication is needed to delete your key pair"
        
        var err:NSError?
        guard context.canEvaluatePolicy(policy, error: &err) else {
            log("cannot eval policy: \(err?.localizedDescription ?? "unknown err")", .error)
            completion(true)
            
            return
        }
        
        
        dispatchMain {
            context.evaluatePolicy(policy, localizedReason: reason, reply: { (success, policyErr) in
                completion(success)
            })
            
        }
        
    }
    
    //MARK: Actions
    
    @IBAction func contactUsTapped() {
        
        guard MFMailComposeViewController.canSendMail() else {
            if let mailURL = URL(string: "mailto://\(Properties.shared.contactUsEmail)") {
                UIApplication.shared.openURL(mailURL)
            }
            
            return
        }
        
        let mailDialogue = MFMailComposeViewController()
        mailDialogue.setToRecipients([Properties.shared.contactUsEmail])
        
        mailDialogue.setSubject("Feedback for Kryptonite \(self.versionLabel.text ?? "")")
        
        // feedback device info
        var deviceInfo = [String:String]()
        deviceInfo["model"] = UIDevice.current.model
        deviceInfo["version"] = UIDevice.current.systemVersion
        deviceInfo["system_name"] = UIDevice.current.systemName
        deviceInfo["arn"] = (try? KeychainStorage().get(key: KR_ENDPOINT_ARN_KEY)) ?? "unknown"
        
        if let deviceInfoJson = try? JSONSerialization.data(withJSONObject: deviceInfo, options: JSONSerialization.WritingOptions.prettyPrinted) {
            mailDialogue.addAttachmentData(deviceInfoJson, mimeType: "plain/text", fileName: "device-info.txt")
        }
        //
        
        mailDialogue.mailComposeDelegate = self
        
        present(mailDialogue, animated: true, completion: nil)
        
        
    }
    
    @IBAction func openSourceTapped() {
        if let url = URL(string: Properties.shared.openSourceURL) {
            UIApplication.shared.openURL(url)
        }
    }
    
    @IBAction func privacyTapped() {
        if let url = URL(string: Properties.shared.privacyPolicyURL) {
            UIApplication.shared.openURL(url)
        }
    }


    //MARK: Delegates
    public func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        Resources.makeAppearences()
        
        controller.dismiss(animated: true, completion: nil)
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
