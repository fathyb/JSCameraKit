//
//  AVRecorder.swift
//  iOS-getUserMedia
//
//  Created by Fathy Boundjadj on 07/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import Foundation
import AVFoundation
import CoreGraphics
import Accelerate

#if os(iOS)
    import UIKit
#else
    import AppKit
#endif


struct YUVBuffer {
    struct YUVPlane {
        var width: Int = 0
        var height: Int = 0
        var data: UnsafeMutableRawPointer? = nil
        var temp: UnsafeMutableRawPointer? = nil
        var source: vImage_Buffer? = nil
        var dest: vImage_Buffer? = nil
    }
    
    var y  = YUVPlane()
    var uv = YUVPlane()
}

class AVRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let captureSession = AVCaptureSession()
    let captureOutput = AVCaptureVideoDataOutput()
    let captureQueue = DispatchQueue(label: "AVCaptureQueue", attributes: .concurrent)
    var captureDevice: AVCaptureDevice? = nil
    var captureInput: AVCaptureDeviceInput? = nil
    let capturePhoto = AVCaptureStillImageOutput()
    
    var width = 0
    var height = 0
    var capturePreset: String?
    
    var onBuffer: ((Data, Data) -> Void)?
    
    var resolution: String?
    var buffer: YUVBuffer = YUVBuffer()
    
    #if os(iOS)
    var captureCallbacks: [(UIImage, (() -> Void))] = []
    #endif
    
    static let presetsMap = getPresets()
    
    static func getPresets() -> [String: String] {
        var presetsMap = [
            "640x480": AVCaptureSessionPreset640x480,
            "1280x720": AVCaptureSessionPreset1280x720
        ]
        
        #if os(iOS)
            presetsMap["1920x1080"] = AVCaptureSessionPreset1920x1080
                
            if #available(iOS 9.0, *) {
                presetsMap["3840x2160"] = AVCaptureSessionPreset3840x2160
            }
            else {
                presetsMap["3840x2160"] = "AVCaptureSessionPreset3840x2160"
            }
        #else
            presetsMap["1920x1080"] = "AVCaptureSessionPreset1920x1080"
            presetsMap["3840x2160"] = "AVCaptureSessionPreset3840x2160"
        #endif
        
        return presetsMap
    }
    
    required override init() {
        super.init()
        
        if let avail = captureOutput.availableVideoCVPixelFormatTypes {
            for obj in avail {
                if
                    let n = obj as? Int,
                    let desc = kCVPixelFormatTypes[UInt32(n)]
                {
                    NSLog("Available format: %@", desc)
                }
            }
        }
        
        captureOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as NSString: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        ]
        captureOutput.setSampleBufferDelegate(self, queue: captureQueue)
        captureOutput.alwaysDiscardsLateVideoFrames = true
        
        captureSession.addOutput(captureOutput)
        captureSession.addOutput(capturePhoto)
    }
    
    func configure(resolution: String, position: String) {
        self.resolution = resolution
        
        setDevice(position: getDevicePosition(position: position), resolution: resolution)

    }
    
    func start(resolution: String, position: String) {
        configure(resolution: resolution, position: position)
        
        captureSession.startRunning()
    }
    
    func takePhoto(completionBlock: @escaping (() -> Void)) {
        var connection: AVCaptureConnection?
        
        for obj in capturePhoto.connections {
            guard
                let con = obj as? AVCaptureConnection,
                let ports = con.inputPorts
            else {
                continue
            }
            
            for obj in ports {
                guard let port = obj as? AVCaptureInputPort else {
                    continue
                }
                
                if port.mediaType == AVMediaTypeVideo {
                    connection = con
                }
            }
        }
        
        capturePhoto.captureStillImageAsynchronously(from: connection) {(buf, err) in
            guard err == nil, let buffer = buf else {
                print(err)
                
                return
            }
            
            guard
                let data = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(buffer),
                let provider = CGDataProvider(data: data as CFData),
                let cgImage = CGImage(
                    jpegDataProviderSource: provider,
                    decode: nil,
                    shouldInterpolate: true,
                    intent: .defaultIntent
                )
            else {
                return
            }
            
            #if os(iOS)
                let image = UIImage(cgImage: cgImage, scale: 1, orientation: .right)
                
                self.captureCallbacks.append((image, completionBlock))
                
                UIImageWriteToSavedPhotosAlbum(
                    image, self, #selector(self.image(image:didFinishSavingWithError:contextInfo:)), nil
                )
            #else
                let home = NSHomeDirectory()
                let pictures = home + "/Pictures/test.jpg"
                let url = URL(fileURLWithPath: pictures)
                
                print("Saving to path : %@", pictures)
                
                self.captureQueue.async {
                    try? data.write(to: url)
                    
                    completionBlock()
                }
            #endif
        }
    }
    
    #if os(iOS)
        func image(
            image: UIImage,
            didFinishSavingWithError error: NSError,
            contextInfo info: UnsafeMutableRawPointer
        ) {
            for i in 0 ..< captureCallbacks.count {
                let (img, block) = captureCallbacks[i]
                
                if img == image {
                    captureCallbacks.remove(at: i)
                    
                    return block()
                }
            }
            
            NSLog("Cannot find UIImage capture callback!")
        }
    #endif
    
    func getDevicePosition(position: String) -> AVCaptureDevicePosition {
        var devicePosition: AVCaptureDevicePosition = .back
        
        if position == "front" {
            devicePosition = .front
        }
        else if position != "back" && position != "default" {
            NSLog("Ignoring unsupported side '%@'", position)
        }
        
        return devicePosition
    }
    
    func isRotated() -> Bool {
        #if os(OSX)
            return false
        #else
            return true
        #endif
    }
    
    func isMirrored(position: AVCaptureDevicePosition) -> Bool {
        #if os(OSX)
            return true
        #else
            return position == .front
        #endif
    }
    
    func isMirrored() -> Bool {
        guard let position = captureDevice?.position else {
            return false
        }
        
        return isMirrored(position: position)
    }
    
    func setOptimalPreset(device: AVCaptureDevice) {
        let preset = AVRecorder.presetsMap[self.resolution!]!
        let perfect = ConstraintsManager.getPerfectPreset(
            minPreset: AVCaptureSessionPreset640x480,
            maxPreset: AVCaptureSessionPreset1280x720,
            optimal: preset,
            device: device
        )
        
        captureSession.sessionPreset = perfect
            
        let resolution = ConstraintsManager.presets[captureSession.sessionPreset]!
            
        width = resolution.width
        height = resolution.height
    }
    
    func setResolution(resolution: String) {
        self.resolution = resolution
            
        captureSession.beginConfiguration()
        
        setOptimalPreset(device: captureDevice!)
            
        captureSession.commitConfiguration()
    }
    
    func setDevice(position: AVCaptureDevicePosition, resolution: String) {
        var dev: AVCaptureDevice?
        
        #if os(OSX)
            dev = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        #else
            if #available(iOS 10.0, *) {
                dev = AVCaptureDevice.defaultDevice(
                    withDeviceType: .builtInWideAngleCamera,
                    mediaType: AVMediaTypeVideo,
                    position: position
                )
            }
            else {
                guard let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) else {
                    return
                }
                
                for obj in devices {
                    let device = obj as? AVCaptureDevice
                    
                    if device?.position == position {
                        dev = device
                        break
                    }
                }
            }
        #endif
        
        guard let device = dev else {
            return
        }
        
        captureSession.beginConfiguration()
        
        for obj in captureSession.inputs {
            guard let input = obj as? AVCaptureInput else {
                continue
            }
            
            captureSession.removeInput(input)
        }
        
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        setOptimalPreset(device: device)
        
        captureSession.addInput(input)
        captureSession.commitConfiguration()

        captureInput = input
        captureDevice = device
        
        #if os(OSX)
            var format = AVCaptureDeviceFormat()
            let targetFps: Double = 60
            var maxFps: Double = 0
            
            for anyFormat in device.formats {
                guard
                    let vFormat = anyFormat as? AVCaptureDeviceFormat,
                    let ranges = vFormat.videoSupportedFrameRateRanges as? [AVFrameRateRange]
                else {
                    continue
                }
                
                let frameRates = ranges[0]

                if frameRates.maxFrameRate >= maxFps && frameRates.maxFrameRate <= targetFps {
                    maxFps = frameRates.maxFrameRate
                    format = vFormat
                }
            }
            
            
            NSLog("Max FPS : %d", maxFps)
            try! device.lockForConfiguration()
            
            device.activeFormat = format
            device.activeVideoMinFrameDuration = CMTimeMake(1, Int32(maxFps))
            device.activeVideoMaxFrameDuration = CMTimeMake(1, Int32(maxFps))
            
            device.unlockForConfiguration()
        #endif
    }
    
    func changePosition(position: String) {
        #if os(iOS)
            let position = getDevicePosition(position: position)
            
            setDevice(position: position, resolution: resolution!)
        #endif
    }
    
    func stop() {
        captureSession.stopRunning()
    }
    func onCapture(output: AVCaptureOutput!, sample: CMSampleBuffer!, connection: AVCaptureConnection!) {
        let img = CMSampleBufferGetImageBuffer(sample)!
        let flag = CVPixelBufferLockFlags.readOnly
        
        CVPixelBufferLockBaseAddress(img, flag)
        
        let  yRow = CVPixelBufferGetBytesPerRowOfPlane(img, 0)
        let uvRow = CVPixelBufferGetBytesPerRowOfPlane(img, 1)
        
        let  yWidth = CVPixelBufferGetWidthOfPlane(img, 0)
        let uvWidth = CVPixelBufferGetWidthOfPlane(img, 1)
        
        let  yHeight = CVPixelBufferGetHeightOfPlane(img, 0)
        let uvHeight = CVPixelBufferGetHeightOfPlane(img, 1)
        
        let  yBuf = CVPixelBufferGetBaseAddressOfPlane(img, 0)!
        let uvBuf = CVPixelBufferGetBaseAddressOfPlane(img, 1)!
        
        var yData: Data?, uvData: Data?
        
        if #available(iOS 10.0, OSX 10.12, *), yWidth != width && yHeight != height {
            let dYW = Double(yWidth), dYH = Double(yHeight)
            let dUVH = Double(uvHeight)
            
            let fx = Double(width) / dYW
            let fy = Double(height) / dYH
            let destYRow = Int(Double(yRow) * fx)
            let destUVRow = Int(Double(uvRow) * fx)
            let destYH = Int(dYH * fy)
            let destUVH = Int(dUVH * fy)
            
            allocYUVBuffer(
                yWidth: yWidth,
                uvWidth: uvWidth,
                yHeight: yHeight,
                uvHeight: uvHeight,
                yRow: yRow,
                uvRow: uvRow
            )
            
            
            vImageScale_Planar8(
                &buffer.y.source!, &buffer.y.dest!,
                buffer.y.temp, vImage_Flags(kvImageNoAllocate)
            )
            vImageScale_CbCr8(
                &buffer.uv.source!, &buffer.uv.source!,
                buffer.uv.temp, vImage_Flags(kvImageNoAllocate)
            )
            
            yData = Data(
                bytesNoCopy: buffer.y.data!,
                count: destYRow * destYH,
                deallocator: .none
            )
            uvData = Data(
                bytesNoCopy: buffer.uv.data!,
                count: destUVRow * destUVH,
                deallocator: .none
            )
        }
        else {
            yData = Data(
                bytesNoCopy: yBuf,
                count: yRow * yHeight,
                deallocator: .none
            )
            uvData = Data(
                bytesNoCopy: uvBuf,
                count: uvRow * uvHeight,
                deallocator: .none
            )
            
            //freeYUVBuffer()
        }
        
        onBuffer?(yData!, uvData!)
        
        CVPixelBufferUnlockBaseAddress(img, flag)
    }
    
    func allocYUVBuffer(
        yWidth: Int, uvWidth: Int, yHeight: Int, uvHeight: Int, yRow: Int, uvRow: Int
    ) {
        if
            width != buffer.y.width || height != buffer.y.height ||
            width != buffer.uv.width || height != (buffer.uv.height * 2) ||
            buffer.y.data == nil || buffer.uv.data == nil
        {
            let dYW = Double(yWidth), dYH = Double(yHeight)
            let dUVW = Double(uvWidth), dUVH = Double(uvHeight)
            
            let fx = Double(width) / dYW
            let fy = Double(height) / dYH
            let destYRow = Int(Double(yRow) * fx)
            let destUVRow = Int(Double(uvRow) * fx)
            
            
            freeYUVBuffer()
            
            buffer.y.width = width
            buffer.y.height = height
            buffer.y.data = malloc(width * height)
            
            buffer.uv.width = width
            buffer.uv.height = height / 2
            buffer.uv.data = malloc(width * (height / 2))
            
            buffer.y.source = vImage_Buffer(
                data: nil,
                height: vImagePixelCount(yHeight),
                width: vImagePixelCount(yWidth),
                rowBytes: yRow
            )
            buffer.y.dest = vImage_Buffer(
                data: buffer.y.data,
                height: vImagePixelCount(dYH * fy),
                width: vImagePixelCount(dYW * fx),
                rowBytes: destYRow
            )
            
            buffer.uv.source = vImage_Buffer(
                data: nil,
                height: vImagePixelCount(uvHeight),
                width: vImagePixelCount(uvWidth),
                rowBytes: uvRow
            )
            buffer.uv.dest = vImage_Buffer(
                data: buffer.uv.data,
                height: vImagePixelCount(dUVH * fy),
                width: vImagePixelCount(dUVW * fx),
                rowBytes: destUVRow
            )
            
            
            var size = vImageScale_Planar8(
                &buffer.y.source!, &buffer.y.dest!,
                nil, vImage_Flags(kvImageGetTempBufferSize)
            )
                
            buffer.y.temp = malloc(size)
            
            if #available(iOS 10.0, OSX 10.12, *) {
                size = vImageScale_CbCr8(
                    &buffer.uv.source!, &buffer.uv.dest!,
                    nil, vImage_Flags(kvImageGetTempBufferSize)
                )
                
                buffer.uv.temp = malloc(size)
            }
            else {
                NSLog("WARNING: Downscaling only supported on iOS 10+")
            }
            
            NSLog("YUV Buffer generated")
        }
    }
    
    func freeYUVBuffer() {
        if buffer.y.data != nil {
            free(buffer.y.data)
            
            buffer.y.data = nil
        }
        if buffer.uv.data != nil {
            free(buffer.uv.data)
            
            buffer.uv.data = nil
        }
        
        if buffer.y.temp != nil {
            free(buffer.y.temp)
            
            buffer.y.temp = nil
        }
        if buffer.uv.temp != nil {
            free(buffer.uv.temp)
            
            buffer.uv.temp = nil
        }
        
        buffer.y.width   = 0
        buffer.y.height  = 0
        buffer.uv.width  = 0
        buffer.uv.height = 0
        
        buffer.y.source  = nil
        buffer.y.dest    = nil
        buffer.uv.source = nil
        buffer.uv.dest   = nil
    }
    
    func captureOutput(_
        captureOutput: AVCaptureOutput!,
        didOutputSampleBuffer sample: CMSampleBuffer!,
        from connection: AVCaptureConnection!) {
        onCapture(output: captureOutput, sample: sample, connection: connection)
    }
}
