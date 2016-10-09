//
//  CDVJSCameraKit.h
//  JSCameraKit
//
//  Created by Fathy Boundjadj on 10/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Cordova/CDVPlugin.h>

@import JSCameraKit.Swift;

@interface CDVJSCameraKit : CDVPlugin

@property (nonatomic) WebSocketCamera* cameraServer;

@end
