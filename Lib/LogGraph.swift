//
//  LogGraph.swift
//  krSSH
//
//  Created by Alex Grinman on 9/14/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation


class LogGraph:UIView {
    
    var fillColor = UIColor.black
    var bars:[UIView] = []
    var bucketSize = 48
    var zeroRatio = 0.1
    
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        prepareBars()
    }
    
    
    func prepareBars() {
        if bars.isEmpty == false {
            return
        }
        
        
        let bucketWidth = bounds.size.width/CGFloat(bucketSize)
        let height = bounds.size.height
        log("bw: \(bucketWidth), bh: \(height)")

        for i in 0 ..< bucketSize {
            let bar = UIView(frame: CGRect(x: CGFloat(i)*bucketWidth, y: CGFloat(1-zeroRatio)*height, width: bucketWidth, height: height))
            bar.backgroundColor = fillColor
            addSubview(bar)
            bars.append(bar)
        }
    }
    
    func set(values:[Date]) {
        
        let sorted = values.filter({ abs($0.timeIntervalSinceNow) < 2*Double(TimeSeconds.day.rawValue) }).sorted(by: { $0 < $1 })
        
        var counts = [Int](repeating: 0, count: bucketSize)
        
        for i in 0 ..< bucketSize {
            
            let curr = Double((bucketSize - i)*TimeSeconds.hour.rawValue)
            let next = Double((bucketSize - i - 1)*TimeSeconds.hour.rawValue)
            
            for date in sorted {
                guard
                    abs(date.timeIntervalSinceNow) <= curr &&
                    abs(date.timeIntervalSinceNow) > next
                else {
                    continue
                }
                
                counts[i] += 1
            }
        }
        
        let sortedCounts = counts.sorted(by: { $0 < $1 })
        let maxCount = sortedCounts[bucketSize - 1]
        let minCount = sortedCounts[0]
        
        for i in 0 ..< bucketSize {
            
            var ratio = zeroRatio
            if maxCount > 0 {
                ratio += Double(counts[i] - minCount)/Double(maxCount)
            }
            
            ratio = min(ratio, 1.0)
    
            dispatchMain {
                self.bars[i].backgroundColor = self.fillColor
                self.bars[i].frame.origin.y = CGFloat(1 - ratio)*self.frame.size.height
            }
        }
        
    }
    
}
