//
//  LoadingController.swift
//  Krypton
//
//  Created by Alex Grinman on 12/1/17.
//  Copyright © 2017 KryptCo. All rights reserved.
//

import Foundation
import UIKit

extension LoadingController {
    static func present(from: UIViewController) -> LoadingController? {
        guard let loading =  Resources.Storyboard.Loading.instantiateViewController(withIdentifier: "LoadingController") as? LoadingController else {
            return nil
        }
        loading.modalTransitionStyle = UIModalTransitionStyle.crossDissolve
        loading.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext

        from.present(loading, animated: true, completion: nil)
        return loading
    }
}

class LoadingController:UIViewController {
    
    @IBOutlet weak var checkBox:M13Checkbox!
    @IBOutlet weak var arcView:UIView!
    @IBOutlet weak var blurView:UIVisualEffectView!
    @IBOutlet weak var blurBackgroundView:UIVisualEffectView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        blurBackgroundView.setBorder(color: UIColor.clear, cornerRadius: 8.0, borderWidth: 0.0)
        blurView.setBorder(color: UIColor.clear, cornerRadius: 8.0, borderWidth: 0.0)

        for v in [blurBackgroundView] {
            v?.layer.shadowColor = UIColor.black.cgColor
            v?.layer.shadowOffset = CGSize(width: 0, height: 0)
            v?.layer.shadowOpacity = 0.125
            v?.layer.shadowRadius = 3
            v?.layer.masksToBounds = false
        }

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        arcView.spinningArc(lineWidth: checkBox.checkmarkLineWidth, ratio: 0.5)
    }
    
    func showSuccess(hideAfter interval:TimeInterval, then:(()->())? = nil) {
        dispatchMain {
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
            }) { (_) in
                self.checkBox.toggleCheckState(true)
                dispatchAfter(delay: interval) {
                    self.dismiss(animated: true, completion: then)
                }
            }
        }
    }
    
    func showError(hideAfter interval:TimeInterval, title:String, error:String, then:(()->())? = nil) {
        dispatchMain {
            self.checkBox.secondaryCheckmarkTintColor = UIColor.reject
            self.checkBox.tintColor = UIColor.reject
            
            UIView.animate(withDuration: 0.3, animations: {
                self.arcView.alpha = 0
            }) { (_) in
                self.checkBox.setCheckState(M13Checkbox.CheckState.mixed, animated: true)

                dispatchAfter(delay: interval, task: {
                    self.showWarning(title: title, body: error) {
                        self.dismiss(animated: true, completion: then)
                    }
                })
            }
            
        }

    }
}
