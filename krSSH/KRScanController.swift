//
//  KRScanController.swift
//  Kryptonite
//
//  Created by Alex Grinman on 1/8/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import UIKit
import AudioToolbox
import AVFoundation

protocol KRScanDelegate {
    func onFound(data:String) -> Bool
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
        
        self.focusMarkLayer.strokeColor = UIColor.red.cgColor
        self.cornersLayer.strokeColor = UIColor(hex: 0x3FC380).cgColor
        self.cornersLayer.strokeWidth = 6.0

        if self.output.availableMetadataObjectTypes.contains(where: {$0 as? String ?? "" == AVMetadataObjectTypeQRCode}) {
            self.output.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        }
        
        self.barcodesHandler = { barcodes in
            guard self.canScan else {
                return
            }
            
            if let data = barcodes.first?.stringValue {
                let didDecode = self.delegate?.onFound(data: data) ?? false
                
                self.canScan = !didDecode
                
                if didDecode {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                }

            }
        }
        
        
    }
}
