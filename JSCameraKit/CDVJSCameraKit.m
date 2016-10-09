//
//  CDVJSCameraKit.m
//  JSCameraKit
//
//  Created by Fathy Boundjadj on 10/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

#import "CDVJSCameraKit.h"

@implementation CDVJSCameraKit

-(void)pluginInitialize {
    _cameraServer = [[WebSocketCamera alloc] init];
}
@end
