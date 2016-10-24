//
//  getPixelFormat.swift
//  JSCameraKit
//
//  Created by Fathy Boundjadj on 22/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import Foundation

let kCVPixelFormatTypes: [OSType: String] = [
    kCVPixelFormatType_1Monochrome: "kCVPixelFormatType_1Monochrome",
    kCVPixelFormatType_2Indexed: "kCVPixelFormatType_2Indexed",
    kCVPixelFormatType_4Indexed: "kCVPixelFormatType_4Indexed",
    kCVPixelFormatType_8Indexed: "kCVPixelFormatType_8Indexed",
    kCVPixelFormatType_1IndexedGray_WhiteIsZero: "kCVPixelFormatType_1IndexedGray_WhiteIsZero",
    kCVPixelFormatType_2IndexedGray_WhiteIsZero: "kCVPixelFormatType_2IndexedGray_WhiteIsZero",
    kCVPixelFormatType_4IndexedGray_WhiteIsZero: "kCVPixelFormatType_4IndexedGray_WhiteIsZero",
    kCVPixelFormatType_8IndexedGray_WhiteIsZero: "kCVPixelFormatType_8IndexedGray_WhiteIsZero",
    kCVPixelFormatType_16BE555: "kCVPixelFormatType_16BE555",
    kCVPixelFormatType_16LE555: "kCVPixelFormatType_16LE555",
    kCVPixelFormatType_16LE5551: "kCVPixelFormatType_16LE5551",
    kCVPixelFormatType_16BE565: "kCVPixelFormatType_16BE565",
    kCVPixelFormatType_16LE565: "kCVPixelFormatType_16LE565",
    kCVPixelFormatType_24RGB: "kCVPixelFormatType_24RGB",
    kCVPixelFormatType_24BGR: "kCVPixelFormatType_24BGR",
    kCVPixelFormatType_32ARGB: "kCVPixelFormatType_32ARGB",
    kCVPixelFormatType_32BGRA: "kCVPixelFormatType_32BGRA",
    kCVPixelFormatType_32ABGR: "kCVPixelFormatType_32ABGR",
    kCVPixelFormatType_32RGBA: "kCVPixelFormatType_32RGBA",
    kCVPixelFormatType_64ARGB: "kCVPixelFormatType_64ARGB",
    kCVPixelFormatType_48RGB: "kCVPixelFormatType_48RGB",
    kCVPixelFormatType_32AlphaGray: "kCVPixelFormatType_32AlphaGray",
    kCVPixelFormatType_16Gray: "kCVPixelFormatType_16Gray",
    kCVPixelFormatType_422YpCbCr8: "kCVPixelFormatType_422YpCbCr8",
    kCVPixelFormatType_4444YpCbCrA8: "kCVPixelFormatType_4444YpCbCrA8",
    kCVPixelFormatType_4444YpCbCrA8R: "kCVPixelFormatType_4444YpCbCrA8R",
    kCVPixelFormatType_444YpCbCr8: "kCVPixelFormatType_444YpCbCr8",
    kCVPixelFormatType_422YpCbCr16: "kCVPixelFormatType_422YpCbCr16",
    kCVPixelFormatType_422YpCbCr10: "kCVPixelFormatType_422YpCbCr10",
    kCVPixelFormatType_444YpCbCr10: "kCVPixelFormatType_444YpCbCr10",
    kCVPixelFormatType_420YpCbCr8Planar: "kCVPixelFormatType_420YpCbCr8Planar",
    kCVPixelFormatType_420YpCbCr8PlanarFullRange: "kCVPixelFormatType_420YpCbCr8PlanarFullRange",
    kCVPixelFormatType_422YpCbCr_4A_8BiPlanar: "kCVPixelFormatType_422YpCbCr_4A_8BiPlanar",
    kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: "kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange",
    kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: "kCVPixelFormatType_420YpCbCr8BiPlanarFullRange",
    kCVPixelFormatType_422YpCbCr8_yuvs: "kCVPixelFormatType_422YpCbCr8_yuvs",
    kCVPixelFormatType_422YpCbCr8FullRange: "kCVPixelFormatType_422YpCbCr8FullRange"
]
