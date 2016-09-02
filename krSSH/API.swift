//
//  API.swift
//  krSSH
//
//  Created by Alex Grinman on 9/2/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

enum AWSConfKey:String {
    case sns = "kr-sns"
    case sqs = "kr-sqs"
}


struct UnknownAWSRequestError:Error {}
struct BadAWSRequestError:Error {}
enum APIResult {
    case message([String])
    case sent
    case failure(Error)
}

typealias QueueName = String

extension QueueName {
    var url:String {
        return self
    }
}


class API {
    
    var snsClient = AWSSNS(forKey: AWSConfKey.sns.rawValue)
    var sqsClient = AWSSQS(forKey: AWSConfKey.sqs.rawValue)
    
    class func provision(accessKey:String, secretKey:String) -> Bool {
        let snsCreds = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let snsConf = AWSServiceConfiguration(region: AWSRegionType.usEast1, credentialsProvider: snsCreds)
        
        let sqsCreds = AWSStaticCredentialsProvider(accessKey: accessKey, secretKey: secretKey)
        let sqsConf = AWSServiceConfiguration(region: AWSRegionType.usEast1, credentialsProvider: sqsCreds)

        guard let sns = snsConf, let sqs = sqsConf else {
            return false
        }

        AWSSNS.register(with: sns, forKey: AWSConfKey.sns.rawValue)
        AWSSQS.register(with: sqs, forKey: AWSConfKey.sqs.rawValue)
        
        return true
    }
    
    init() {}
    
    
    
    
    //MARK: SNS
    
    
    //MARK: SQS
    func send(to:QueueName, message:String, handler:((APIResult)->Void)) {
        guard let request = AWSSQSSendMessageRequest() else {
            return
        }
        
        request.messageBody = message
        request.queueUrl = to.url
        
        sqsClient.sendMessage(request) { (result, err) in
            guard err == nil else {
                handler(APIResult.failure(err!))
                return
            }
            
            handler(APIResult.sent)
        }
    }
    
    func receive(_ on:QueueName, handler:((APIResult)->Void)) {
        guard let request = AWSSQSReceiveMessageRequest() else {
            log("Cannot create `receive request` for queue \(on)", LogType.error)
            handler(APIResult.failure(BadAWSRequestError()))
            return
        }
        
        request.queueUrl = on.url
        request.waitTimeSeconds = 10
        
        sqsClient.receiveMessage(request) { (result, err) in
            guard let sqsMsgs = result?.messages, err == nil else {
                handler(APIResult.failure(err ?? UnknownAWSRequestError()))
                return
            }
            
            var messages = [String]()
            
            var receiptEntries = [AWSSQSDeleteMessageBatchRequestEntry]()
            
            for msg in sqsMsgs {
                if let data = msg.body {
                    messages.append(data)
                }
                
                if let entry = AWSSQSDeleteMessageBatchRequestEntry() {
                    entry.identifier = msg.messageId
                    entry.receiptHandle = msg.receiptHandle
                    receiptEntries.append(entry)
                }
            }
            
            if let batchDeleteRequest = AWSSQSDeleteMessageBatchRequest() {
                batchDeleteRequest.queueUrl = on.url
                batchDeleteRequest.entries = receiptEntries
                
                self.sqsClient.deleteMessageBatch(batchDeleteRequest)
                
            }
            
            
            handler(APIResult.message(messages))
        }
    }
    
}
