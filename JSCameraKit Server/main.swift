//
//  main.swift
//  JSCameraKit Server
//
//  Created by Fathy Boundjadj on 13/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

import Foundation
import JSCameraKit_macOS

let runLoop = RunLoop.current
let server = WebSocketCamera()

while(runLoop.run(mode: RunLoopMode.defaultRunLoopMode, before: NSDate.distantFuture)) {
    // The RunLoop is only used by the activity timer, we can wait 500ms
    usleep(500 * 1000)
}
