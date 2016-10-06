//
//  UIView+KR.swift
//  Kryptonite
//
//  Created by Alex Grinman on 9/18/16.
//  Copyright © 2016 KryptCo, Inc. All rights reserved.
//

import Foundation

extension UIView {
    
    func pulse(scale:CGFloat, duration:TimeInterval) {
        
        UIView.animate(withDuration: duration, delay: 0.0, options:  [UIViewAnimationOptions.allowUserInteraction, UIViewAnimationOptions.autoreverse, UIViewAnimationOptions.repeat], animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)

            }, completion: nil)
    }
    
    func stopAnimations() {
        self.layer.removeAllAnimations()
    }
}
