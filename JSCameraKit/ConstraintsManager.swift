//
//  ConstraintsManager.swift
//  JSCameraKit
//
//  Created by Fathy Boundjadj on 22/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import AVFoundation

struct Resolution {
    var width: Int
    var height: Int
}

class ConstraintsManager: NSObject {
    static let presets = getPresets()
    
    static func getPresets() -> [String: Resolution] {
        var presets = [
            AVCaptureSessionPreset352x288 : Resolution(width: 352,  height: 288),
            AVCaptureSessionPreset640x480 : Resolution(width: 640,  height: 480),
            AVCaptureSessionPreset1280x720: Resolution(width: 1280, height: 720)
        ]
        
        #if os(iOS)
            presets[AVCaptureSessionPreset1920x1080] = Resolution(width: 1920, height: 1080)
        #endif
        
        return presets
    }
    
    static func getPerfectPreset(
        minPreset: String, maxPreset: String, optimal: String,
        device: AVCaptureDevice
    ) -> String {
        // I don't know if it's an OSX bug, but even if canSessionPreset returns true AVFoundation keeps sending 720p frames
        #if os(OSX)
            return AVCaptureSessionPreset1280x720
        #else
            let min = presets[minPreset]!
            let max = presets[maxPreset]!
            let minSize = min.width * min.height
            let maxSize = max.width * max.height
            
            if device.supportsAVCaptureSessionPreset(optimal) {
                return optimal
            }
            
            for (preset, res) in presets {
                let size = res.width * res.height
                
                if size <= maxSize && size >= minSize {
                    if device.supportsAVCaptureSessionPreset(preset) {
                        return preset
                    }
                }
            }
            
            return AVCaptureSessionPreset640x480
        #endif
        
    }
}
