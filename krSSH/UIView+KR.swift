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
    
    func spinningArc(lineWidth:CGFloat, ratio:CGFloat = 0.2, color:UIColor = UIColor.app) {
        let frameSize = self.frame.size
        
        let innerCircle = CAShapeLayer()
        innerCircle.path = UIBezierPath(ovalIn: CGRect(x: 0.0, y: 0.0, width: frameSize.width, height: frameSize.height)).cgPath
        
        innerCircle.lineWidth = lineWidth
        innerCircle.strokeStart = 0.1
        innerCircle.strokeEnd = 0.1+ratio
        innerCircle.lineCap = kCALineCapRound
        innerCircle.fillColor = UIColor.clear.cgColor
        innerCircle.strokeColor = color.cgColor
        self.layer.addSublayer(innerCircle)
        
        let rotateAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotateAnimation.toValue = CGFloat(M_PI*2.0)
        rotateAnimation.duration = 1.0
        rotateAnimation.isCumulative = true
        rotateAnimation.repeatCount = .infinity
        self.layer.add(rotateAnimation, forKey: "rotation")
    }
    
    func stopAnimations() {
        self.layer.removeAllAnimations()
    }
    
}
