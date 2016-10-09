//
//  WebSocketCamera.swift
//  iOS-getUserMedia
//
//  Created by Fathy Boundjadj on 09/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
#endif

@objc
public class WebSocketCamera: NSObject {
    let capture = AVRecorder()
    let controller = WebSockerController()
    let queue = DispatchQueue(label: "WebSocketCamera")
    let frameGroup = DispatchGroup()
    let sendGroup = DispatchGroup()
    
    var activityTimer: Timer?
    
    var yBuffer: Data?
    var uvBuffer: Data?
    var initied = false
    var needFrame = false
    var sending = false
    var lastFrame = CACurrentMediaTime()
    
    var resolution: String?
    var position: String?
    
    required override public init() {
        super.init()
        
        controller.addSyncHandler(message: "ping", handler: { _ in return "pong" })
        controller.addSyncHandler(message: "need-frame", handler: {data in
            if
                self.initied == false,
                let resolution = self.resolution,
                let position = self.position
            {
                self.start(resolution: resolution, position: position)
            }
            else if self.yBuffer != nil && self.uvBuffer != nil {
                self.writeFrame()
            }
            else {
                self.needFrame = true
            }
            
            return self.getCaptureInfos()
        })
        
        controller.addSyncHandler(message: "configure", handler: {data in
            if
                let json = data as? [String: Any],
                let resolution = json["resolution"] as? String,
                let position = json["position"] as? String
            {
                self.start(resolution: resolution, position: position)
            }
            
            return self.getCaptureInfos()
        })
        controller.addSyncHandler(message: "get-configuration", handler: {_ in
            return self.getCaptureInfos()
        })
        controller.addSyncHandler(message: "change-position", handler: {data in
            if let position = data as? String {
                NSLog("Change position to %@", position)
                
                self.clear()
                self.capture.changePosition(position: position)
            }
            
            return self.getCaptureInfos()
        })
        controller.addSyncHandler(message: "change-resolution", handler: {data in
            if let resolution = data as? String {
                NSLog("Change resolution to %@", resolution)
                
                self.clear()
                self.capture.setResolution(resolution: resolution)
            }
            
            return self.getCaptureInfos()
        })
        controller.addAsyncHandler(message: "capture-photo", handler: {_, block in
            self.capture.takePhoto(completionBlock: {
                NSLog("TakePhoto completionBlock called!")
                
                block(nil)
            })
        })
        
        #if os(iOS)
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(didEnterBackground),
                name: NSNotification.Name.UIApplicationDidEnterBackground,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(willEnterForeground),
                name: NSNotification.Name.UIApplicationWillEnterForeground,
                object: nil
            )
        #endif
        
        capture.onBuffer = {yData, uvData -> Void in
            self.yBuffer = yData
            self.uvBuffer = uvData
            
            if self.needFrame == true {
                self.writeFrame()
            }
        }
    }
    
    func getCaptureInfos() -> [String:Any] {
        return [
            "width": self.capture.width,
            "height": self.capture.height,
            "mirrored": self.capture.isMirrored(),
            "rotated": self.capture.isRotated()
        ]
    }
    #if os(iOS)
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    #endif
    
    func clear() {
        controller.webSocket.cancelAllWrites()

        needFrame = false
        yBuffer = nil
        uvBuffer = nil
    }
    
    func didEnterBackground() {
        NSLog("App will enter background mode")
        
        controller.webSocket.pause()
    }
    
    func willEnterForeground() {
        controller.webSocket.start()
    }
    
    
    func stop() {
        initied = false
        capture.stop()
    }
    
    func start(resolution: String, position: String) {
        if self.initied == false {
            NSLog("Setting up camera with resolution %@ and side %@", resolution, position)
            
            self.resolution = resolution
            self.position = position
            self.initied = true
            
            self.capture.start(resolution: resolution, position: position)
        }
    }
    
    func writeFrame() {
        let now = CACurrentMediaTime()
        
        if sending && (now - lastFrame) >= 1 {
            NSLog("Invalidating sending lock after 1000 ms")
            
            sending = false
        }
        
        if initied == true && !sending {
            guard let y = yBuffer, let uv = uvBuffer else {
                return
            }
            
            sending = true
            lastFrame = now
            needFrame = false
            
            let yHead = Data(bytes: [0])
            let uvHead = Data(bytes: [1])
            
            setActivityTimer()
            
            sendGroup.enter()
            sendGroup.enter()
            
            controller.webSocket.write([yHead, y], withCompletionBlock: {
                self.sendGroup.leave()
            })
            controller.webSocket.write([uvHead, uv], withCompletionBlock: {
                self.sendGroup.leave()
            })
            
            queue.async {
                self.sendGroup.wait()
                
                self.clearFrameData()
            }
        }
    }
    
    func clearFrameData() {
        yBuffer = nil
        uvBuffer = nil
        needFrame = false
        sending = false
    }
    
    func activityTimeout() {
        NSLog("No camera activity since 5 seconds, stopping camera.")
        
        self.stop()
    }
    
    func setActivityTimer() {
        capture.captureQueue.async {
            self.activityTimer?.invalidate()
            self.activityTimer = Timer.scheduledTimer(
                timeInterval: 5,
                target: self,
                selector: #selector(self.activityTimeout),
                userInfo: nil,
                repeats: false
            )
        }
    }
}
