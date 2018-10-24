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
            
            let didDecode = self.delegate?.onFound(data: data) ?? false
            
            self.canScan = !didDecode
            
            if didDecode {
                dispatchMain { UIImpactFeedbackGenerator(style: UIImpactFeedbackStyle.heavy).impactOccurred() }
            }
        }
    }
}
