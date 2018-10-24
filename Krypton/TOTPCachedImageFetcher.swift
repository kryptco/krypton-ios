//
//  TOTPCachedImageFetcher.swift
//  Krypton
//
//  Created by Alex Grinman on 10/12/18.
//  Copyright © 2018 KryptCo. All rights reserved.
//

import Foundation
import SwiftHTTP

class TOTPCachedImageFetcher {
    
    enum Errors:Error {
        case noCacheDir
        case badFilenameEncoding
    }
    let imageCache:URL
    
    private let remoteImagesURL = "https://s3.us-east-2.amazonaws.com/serviceicons.krypt.co/"
    
    init() throws {
        let cacheDir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        
        let imagesPath = cacheDir.appendingPathComponent("totp_images")
        try FileManager.default.createDirectory(at: imagesPath, withIntermediateDirectories: true, attributes: nil)
        
        self.imageCache = imagesPath
    }
    
    func loadImage(for issuerName:String, onImage:@escaping ((UIImage?) -> Void)) throws {
        guard let filename = "\(issuerName.lowercased()).png".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw Errors.badFilenameEncoding
        }
        
        let filePath = imageCache.appendingPathComponent(filename).path
        guard   FileManager.default.fileExists(atPath: filePath),
                let image = UIImage(contentsOfFile: filePath)
        else {
            loadImageFromNetwork(for: filename, onImage: onImage)
            return
        }
        
        onImage(image)
    }
    
    private func loadImageFromNetwork(for percentEncodedName:String, onImage:@escaping ((UIImage?) -> Void)) {        
        let desiredFilePath = imageCache.appendingPathComponent(percentEncodedName)

        HTTP.GET("\(remoteImagesURL)\(percentEncodedName)") { resp in
            log("resp: \(resp)")
            
            guard resp.error == nil else {
                log("error loading image: \(resp.error!)", .error)
                onImage(nil)
                return
            }
            
        
            
            do {
                try resp.data.write(to: desiredFilePath, options: .atomic)
            } catch {
                log("error saving image", .error)
                onImage(nil)
                return
            }
            
            let image = UIImage(contentsOfFile: desiredFilePath.path)
            onImage(image)
        }
    }
}
