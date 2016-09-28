//
//  ExchangeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation
import LocalAuthentication

class PairController: KRBaseController, KRScanDelegate {
    
    var scanViewController:KRScanController?
    @IBOutlet weak var scanRails:UIImageView!

    @IBOutlet weak var blurView:UIView!
    
    @IBOutlet weak var popupView:UIView!
    @IBOutlet weak var subjectLabel:UILabel!
    @IBOutlet weak var messageLabel:UILabel!
    
    @IBOutlet weak var rejectButton:UIButton!
    @IBOutlet weak var approveButton:UIButton!
    
    @IBOutlet weak var result:UIImageView!
    
    
    static var isAuthenticated:Bool = false
    
    enum Scanned {
        case peer(Peer)
        case pairing(Pairing)
        
        var subject:String {
            switch self {
            case .peer(let p):
                return p.email.uppercased()
            case .pairing(let p):
                return p.name.uppercased()
            }
        }
        
        var message:String {
            switch self {
            case .peer(let p):
                return "Do you want save this as \(p.email)'s public key?"
            case .pairing(let p):
                return "Do you want to pair with \"\(p.name)\"? This device will be able to request SSH logins using your private key."
            }
        }
    }

    var currentScanned:Scanned?


    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        popupView.isHidden = true
        blurView.isHidden = true
        result.isHidden = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.barTintColor = UIColor.app
        
        rejectButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit
        approveButton.imageView?.contentMode = UIViewContentMode.scaleAspectFit

        self.scanViewController?.canScan = true
    }
    
    
    
    var shouldShowProfile = true
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let scanner = segue.destination as? KRScanController {
            self.scanViewController = scanner
            scanner.delegate = self
        }
    }
    
    //MARK: Animate Popover
    
    func showPopup(scanned:Scanned) {
        subjectLabel.text = scanned.subject
        messageLabel.text = scanned.message
        
        popupView.alpha = 0
        blurView.alpha = 0

        popupView.isHidden = false
        blurView.isHidden = false
        
        UIView.animate(withDuration: 0.5) {
            self.popupView.alpha = 1
            self.blurView.alpha = 1
        }
   
    }
    
    func hidePopup(success:Bool) {
        
        if success {
            result.image = ResultImage.check.image
        } else {
            result.image = ResultImage.x.image
        }
        
        result.alpha = 0
        result.isHidden = false

        UIView.animate(withDuration: 0.5, animations:
            {
                self.popupView.alpha = 0
                self.result.alpha = 1
                
                
        }) { (s) in
            self.popupView.isHidden = true
            
            UIView.animate(withDuration: 1.0, animations: {
                self.result.alpha = 0
                //self.blurView.alpha = 0

                }, completion: { (_) in
                    self.result.isHidden = true
                    self.blurView.isHidden = true
                    self.scanViewController?.canScan = true
            })}
    }
        
    //MARK: Accept Reject
        
    @IBAction func acceptTapped() {
        if let scanned = currentScanned {
            approve(scanned: scanned)
        }
        
        currentScanned = nil
    }
    
    @IBAction func rejectTapped() {
        hidePopup(success: false)
        currentScanned = nil
    }
    

    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard   let value = data.data(using: String.Encoding.utf8),
                let json = (try? JSONSerialization.jsonObject(with: value, options: JSONSerialization.ReadingOptions.allowFragments)) as? [String:AnyObject]
        else {
            return false
        }
        
        
        if let peer = try? Peer(json: json) {
            let scanned = Scanned.peer(peer)
            currentScanned = scanned
            dispatchMain { self.showPopup(scanned: scanned) }
            return true
            
        } else if let pairing = try? Pairing(json: json) {
            let scanned = Scanned.pairing(pairing)
            currentScanned = scanned
            dispatchMain { self.showPopup(scanned: scanned) }
            return true
        }
        
    
        return false
    }
    
    
    //MARK: Approve Scanned
    
    func approve(scanned:Scanned) {
        switch scanned {
        case .pairing(let pairing):
            
            authenticate(completion: { (success) in
                guard success else {
                    dispatchMain {
                        self.hidePopup(success: false)
                    }

                    self.showWarning(title: "Authentication Failed", body: "Authentication is needed to pair to a new device.")

                    return
                }
                
                do {
                    let session = try Session(pairing: pairing)
                    SessionManager.shared.add(session: session)
                    Silo.shared.add(session: session)
                    Silo.shared.startPolling(session: session)
                }
                catch let e {
                    log("error creating session: \(e)", .error)
                }
                
                dispatchMain {
                    self.hidePopup(success: true)
                }

                dispatchAfter(delay: 1.0, task: {
                    self.scanViewController?.canScan = true
                })
            })
            


        case .peer(let peer):
            PeerManager.shared.add(peer: peer)
            hidePopup(success: true)
        }
        
        
    }
    
    func authenticate(completion:@escaping (Bool)->Void) {
        let context = LAContext()
        let policy = LAPolicy.deviceOwnerAuthentication
        let reason = "Authentication is needed to pair with a new machine."
        
        var err:NSError?
        guard context.canEvaluatePolicy(policy, error: &err) else {
            log("cannot eval policy: \(err?.localizedDescription ?? "unknown err")", .error)
            completion(true)

            return
        }
        
        
        context.evaluatePolicy(policy, localizedReason: reason, reply: { (success, policyErr) in
            completion(success)
        })

    }

}






