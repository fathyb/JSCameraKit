//
//  WebSocketController.swift
//  JSCameraKit
//
//  Created by Fathy Boundjadj on 24/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import Foundation

typealias SyncMessageHandler = (Any) -> Any?
typealias AsyncMessageHandler = (Any, @escaping (Any?) -> Void) -> Void

class WebSockerController {
    let webSocket = WebSocketServer()
    var  syncHandlers: [String:  SyncMessageHandler] = [:]
    var asyncHandlers: [String: AsyncMessageHandler] = [:]
    
    required init() {
        webSocket.onMessageStringBlock = {message in
            guard let msgData = message?.data(using: .utf8) else {
                return
            }
            
            do {
                guard
                    let json = try JSONSerialization.jsonObject(
                        with: msgData,
                        options: .init(rawValue: 0)
                    ) as? [String:Any],
                    let request = json["request"] as? String,
                    let id = json["id"]
                else {
                    print("Ignoring invalid message")
                        
                    return
                }
                
                self.processMessage(message: request, data: json["data"], completionBlock: {data in
                    var safe = data
                    
                    if safe == nil {
                        safe = ""
                    }
                    
                    let dict = [
                        "id": id,
                        "data": safe!
                    ]
                    
                    self.webSocket.writeJSON(dict, withCompletionBlock: {})
                })
            }
            catch {
                
            }
            
        }
    }
    
    func processMessage(message: String, data: Any?, completionBlock: @escaping (Any?) -> Void) {
        if let async = asyncHandlers[message] {
            async(data, completionBlock)
        }
        else if let sync = syncHandlers[message] {
            completionBlock(sync(data))
        }
    }
    
    func addSyncHandler(message: String, handler: @escaping SyncMessageHandler) {
        if syncHandlers[message] == nil {
            syncHandlers[message] = handler
        }
    }
    
    func addAsyncHandler(message: String, handler: @escaping AsyncMessageHandler) {
        if asyncHandlers[message] == nil {
            asyncHandlers[message] = handler
        }
    }
}
