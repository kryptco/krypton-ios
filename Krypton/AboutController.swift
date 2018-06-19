//
//  AboutController.swift
//  Krypton
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit
import LocalAuthentication
import MessageUI

class AboutController: KRBaseController {

    
    @IBOutlet weak var versionLabel:UILabel!
    @IBOutlet weak var requireU2FApprovalSwitch:UISwitch!
    @IBOutlet weak var analyticsSwitch:UISwitch!
    @IBOutlet weak var destroyButton:UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        requireU2FApprovalSwitch.isOn = Policy.requireUserInteractionU2F
        analyticsSwitch.isOn = !Analytics.enabled

        if  let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            let buildFilePath = Bundle.main.path(forResource: "BUILD", ofType: nil),
            let build = try? String(contentsOfFile: buildFilePath).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
            let commitFilePath = Bundle.main.path(forResource: "COMMIT", ofType: nil),
            let commit = try? String(contentsOfFile: commitFilePath).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        {
            let hashShort = String(commit.prefix(min(6, commit.count)))
            self.versionLabel.text = "\(version).\(build).\(hashShort)"
        } else {
            log("could not find version, build, and commit information", .error)
        }
        
//        if !KeyManager.hasKey() {
//            destroyButton.isHidden = true
//        }
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

    
    @IBAction func requireU2FApprovalChanged(sender:UISwitch) {
        Policy.requireUserInteractionU2F = sender.isOn
    }

    @IBAction func analyticsEnabledChanged(sender:UISwitch) {
        Analytics.set(disabled: sender.isOn)
    }
    
    @IBAction func exportTapped() {
        let logDBPath = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.appGroupSecurityID)!.appendingPathComponent("logs").appendingPathComponent("KryptoniteCoreDataStore.sqlite")
        
        let activityController = UIActivityViewController(activityItems: [logDBPath
            ], applicationActivities: nil)
        
        self.present(activityController, animated: true, completion: nil)

    }
    
    @IBAction func trashTapped() {
        
        let sheet = UIAlertController(title: "Do you want to destroy your private key and reset Krypton?", message: "Your private keys will be gone forever. You will be unpaired from all devices.", preferredStyle: .actionSheet)
        
        sheet.addAction(UIAlertAction(title: "Destroy", style: UIAlertActionStyle.destructive, handler: { (action) in
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

            Analytics.postEvent(category: "keypair", action: "destroy")
            
            let _ = KeyManager.destroyKeyPair()
            IdentityManager.clearMe()
            SessionManager.shared.destroy()
            Onboarding.isActive = true
            
            // delete team identity if it exists (and leave team)
            if case .some(let hasTeam) = try? IdentityManager.hasTeam(), hasTeam {
                self.run(syncOperation: {
                    // remove yourself from the team
                    let _ = try TeamService.shared().appendToMainChainSync(for: .leave)
                    try IdentityManager.removeTeamIdentity()
                    
                }, title: "Leave Team", onSuccess: {
                    dispatchMain {
                        self.dismiss(animated: true, completion: nil)
                    }
                    
                }, onError: {
                    try? IdentityManager.removeTeamIdentity()
                    dispatchMain {
                        self.dismiss(animated: true, completion: nil)
                    }

                })
                
                return
            }
            
            dispatchMain {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        
        let reason = "\(Properties.appName) needs to authenticate you before deleting your key pair."
        
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
            if let mailURL = URL(string: "mailto://\(Properties.contactUsEmail)") {
                UIApplication.shared.open(mailURL, options: [:], completionHandler: nil)
            }
            
            return
        }
        
        let mailDialogue = MFMailComposeViewController()
        mailDialogue.setToRecipients([Properties.contactUsEmail])
        
        mailDialogue.setSubject("Feedback for \(Properties.appName) \(self.versionLabel.text ?? "")")
        
        // feedback device info
        var deviceInfo = "\n\n\n\n\n\n-----------\nDevice Info:\n"
        deviceInfo += "Model: \(UIDevice.current.model)\n"
        deviceInfo += "SystemVersion: \(UIDevice.current.systemVersion)\n"
        deviceInfo += "SystemName: \(UIDevice.current.systemName)\n"
        deviceInfo += "Identifier: \(API.endpointARN ?? "unknown")\n"
        deviceInfo += "-----------"
        //
        mailDialogue.setMessageBody(deviceInfo, isHTML: false)
        mailDialogue.mailComposeDelegate = self
        
        present(mailDialogue, animated: true, completion: nil)
        
        
    }
    
    @IBAction func openSourceTapped() {
        if let url = URL(string: Properties.openSourceURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    @IBAction func privacyTapped() {
        if let url = URL(string: Properties.privacyPolicyURL) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    @IBAction func dismissKnownHostsEditor(segue: UIStoryboardSegue) {
        
    }

    //MARK: Delegates
    public override func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
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
