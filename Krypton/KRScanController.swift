//
//  KRScanController.swift
//  Krypton
//
//  Created by Alex Grinman on 1/8/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import UIKit
import AVFoundation

protocol KRScanDelegate {
    func onFound(data:String) -> Bool
}

enum Redherring {
    case otp
    
    var message:String {
        switch  self {
        case .otp:
            return "This is not a valid Krypton QR code.\n\nKrypton does not yet support one-time passcodes for two-factor. Make sure you install the Krypton Browser Extension and scan the QR code to pair.\n\nMany sites require first setting up a backup two-factor method before adding a security key. You can either use SMS codes or download a one-time passcode app like Google Authenticator."
        }
    }
    
    var prefix:String {
        switch self {
        case .otp:
            return "otpauth://"
        }
    }
    
    static func find(for data:String) -> Redherring? {
        let all:[Redherring] = [.otp]
        
        var found:Redherring?
        all.forEach {
            if data.hasPrefix($0.prefix) {
                found = $0
            }
        }
        
        return found
    }
}
class KRScanController: RSCodeReaderViewController {
    
    var delegate:KRScanDelegate?
    
    private var _canScan:Bool = true
    var canScan:Bool {
        get { return _canScan }
        set(val) {
            _canScan = val
        }
    }
        
    var presenter:UIViewController? {
        return self.parent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.focusMarkLayer.strokeColor = UIColor.reject.cgColor
        self.cornersLayer.strokeColor = UIColor.app.cgColor
        self.cornersLayer.strokeWidth = 4.0
        if self.output.availableMetadataObjectTypes.contains(where: { $0 == .qr }) {
            self.output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        }
        
        self.barcodesHandler = { barcodes in
            guard self.canScan else {
                return
            }
            
            guard let data = barcodes.first?.stringValue else {
                return
            }
            
            if let redherring = Redherring.find(for: data) {
                self.canScan = false
                self.showRedherring(redherring)
                return
            }
            
            let didDecode = self.delegate?.onFound(data: data) ?? false
            
            self.canScan = !didDecode
            
            if didDecode {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
            }
        }
    }
    
    func showRedherring(_ redherring:Redherring) {
        let invalidQRAlert = UIAlertController(title: "Incorrect QR Code", message: redherring.message, preferredStyle: UIAlertControllerStyle.actionSheet)
        
        invalidQRAlert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: { (_) in
            self.canScan = true
        }))
        
        self.present(invalidQRAlert, animated: true, completion: nil)
    }
}
