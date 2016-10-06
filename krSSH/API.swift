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
    case message([NetworkMessage])
    case sent
    case failure(Error)
}

typealias QueueName = String

extension QueueName {
    var url:String {
        return  "\(Properties.shared.awsQueueURLBase)\(self)"
    }
    
    var responder:String {
        return "\(self)-responder"
    }
}


class API {
    
    private var snsClient = AWSSNS(forKey: AWSConfKey.sns.rawValue)
    private var sqsClient = AWSSQS(forKey: AWSConfKey.sqs.rawValue)
    
    class func provision() -> Bool {
        
        let accessKey = Properties.shared.awsAccessKey
        let secretKey = Properties.shared.awsSecretKey
        
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
    
    init() {
    
    }
    
    
    
    
    //MARK: SNS
    func updateSNS(token:String, completionHandler:@escaping ((String?, Error?)->Void)) {
        
        guard let request = AWSSNSCreatePlatformEndpointInput() else {
            return
        }
        
        if isDebug() {
            request.platformApplicationArn = Properties.shared.awsPlatformARN.sandbox

        } else {
            request.platformApplicationArn = Properties.shared.awsPlatformARN.production
        }
        
        request.token = token

        snsClient.createPlatformEndpoint(request) { (resp, err) in
            guard err == nil else {
                log("error getting push: \(err!)", .error)
                completionHandler(nil, err)
                return
            }
            
            completionHandler(resp?.endpointArn, nil)
        }

    }
    
    
    //MARK: SQS
    func send(to:QueueName, message:NetworkMessage, handler:@escaping ((APIResult)->Void)) {
        guard let request = AWSSQSSendMessageRequest() else {
            return
        }
        
        request.messageBody = message.networkFormat().toBase64()
        request.queueUrl = to.responder.url
        
        sqsClient.sendMessage(request) { (result, err) in
            guard err == nil else {
                handler(APIResult.failure(err!))
                return
            }
            
            handler(APIResult.sent)
        }
    }
    
    func receive(_ on:QueueName, handler:@escaping ((APIResult)->Void)) {
        guard let request = AWSSQSReceiveMessageRequest() else {
            log("Cannot create `receive request` for queue \(on)", LogType.error)
            handler(APIResult.failure(BadAWSRequestError()))
            return
        }
        
        request.queueUrl = on.url
        request.waitTimeSeconds = 10
        
        sqsClient.receiveMessage(request) { (result, err) in
            guard err == nil else {
                handler(APIResult.failure(err!))
                return
            }
            
            let sqsMsgs = result?.messages ?? []
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
            
            if let batchDeleteRequest = AWSSQSDeleteMessageBatchRequest(), receiptEntries.count > 0 {
                batchDeleteRequest.queueUrl = on.url
                batchDeleteRequest.entries = receiptEntries
                
                self.sqsClient.deleteMessageBatch(batchDeleteRequest)
                
            }

            var networkMessages : [NetworkMessage] = []
            for message in messages {
                do {
                    let data = try message.fromBase64()
                    try networkMessages.append(NetworkMessage(networkData: data))
                } catch (let e) {
                    log("received malformed message \(message) from SQS with error: \(e)", .warning)
                }
            }
            handler(APIResult.message(networkMessages))
        }
    }
    
}
