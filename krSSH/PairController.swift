//
//  ExchangeController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 6/27/15.
//  Copyright (c) 2015 KryptCo. All rights reserved.
//

import UIKit
import AVFoundation


class PairController: UIViewController, KRScanDelegate {
    

    @IBOutlet var scanViewController:KRScanController?
    @IBOutlet weak var scanRails:UIImageView!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
 
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.barTintColor = UIColor.app
        
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
    

    //MARK: KRScanDelegate
    func onFound(data:String) -> Bool {
        
        guard   let value = data.data(using: String.Encoding.utf8),
                let json = (try? JSONSerialization.jsonObject(with: value, options: JSONSerialization.ReadingOptions.allowFragments)) as? [String:AnyObject]
        else {
            return false
        }
        
        
        if let peer = try? Peer(json: json) {
            PeerManager.shared.add(peer: peer)
            return true
        } else if let pairing = try? Pairing(json: json) {
            do {
                let session = try Session(pairing: pairing)
                SessionManager.shared.add(session: session)
                Silo.shared.add(session: session)
            }
            catch let e {
                log("error creating session: \(e)", .error)
                return false
            }
            dispatchAfter(delay: 1.0, task: {
                self.scanViewController?.canScan = true
            })
            return true
        }
        
    
        return false
    }

}






