# JSCameraKit
Efficient and fast getUserMedia on iOS and macOS!  🎉🎉🎉

## Demo
*the framerate is due to the GIF, it's smooth enough don't worry 😉*

[Cordova/Ionic 2 sample app screencast](http://g.recordit.co/jZDTJzciWq.gif) (too big for Github Camo)

## How it works?

JSCameraKit provides HD camera stream to JavaScript by using WebSockets.
It embeds a small and lightweight server based on the [very good libwebsockets C library](https://github.com/warmcat/libwebsockets).
The WebSocket server sends biplanar YUV frame as binary frames and JavaScript get them and upload them to WebGL textures,
then WebGL get the texture and convert YUV frame to RGB.

## Where it works?

It work on any modern browser running JSCameraKit Server on iOS or macOS.
On macOS a standalone server is provided to test it on any browser.
It require iOS 8+ or macOS 10.9+

## But why not just polyfill `navigator.getUserMedia`?

Because getUserMedia rely on MediaStreams, and MediaStreams are not supported on WebKit.
And JSCameraKit mainly targets Apple devices and intend to give more control over specifics API like camera focus.

## Features
- Works with YUV frames (YUV uses 1.5 byte per pixel, where RGBA uses 4 byte per pixel)
- Uses WebGL for fast color conversion
- Cool WebGL effects included
- Automatic background/sleep management
- Automatic reconnection to server if connection lost
- 0 energy impact when not used
- Support 480p, 720p, 1080p
- 30fps for 480p and 720p
- Very low CPU/RAM footprint (use 2% more CPU than native on an iPhone 6S Plus at 720p@30fps)
- Automatically set the best available preset, for example, if you're using 1080p default resolution, you'll get 1080p on the back camera and 720p on the front

## TODOS

This library was written on a week-end as an experiment so it has work to do

- Video recording, in all resolutions and framerates available
- Record/take picture in a different resolution that the one on preview layer (like record UHD but display 720p)
  - Partial support by using [Accelerate](https://developer.apple.com/reference/accelerate)'s vImage_scale
- Better memory management
- Support more resolutions
- More friendly API
- Add getUserMedia support for Android compatibility

## Known issues
- 1080p may causes somes problems, and has some latency issue (like 15 or 20ms)

## Performance

I'd be glad to see other results on other devices, feel free to send them 🙂

- iPhone 6s Plus running Cordova/Ionic/WKWebView:
  - 420p : 30fps, CPU 10%, RAM 27.6MB, Low energy impact
  - 720p : 30fps, CPU 13%, RAM 31.9MB, High energy impact
  - 1080p: 20fps, CPU 14%, RAM 49.6MB, Very High energy impact

- Macbook Pro Retina 13", i7 3.1GHz, 16GB RAM, running JSCameraKit standalone server:
  - 720p: 30fps, CPU 22%, RAM 11.2MB

## How can we make it faster?

If we could get the WKWebView's JSContext, we would be able to send TypedArray to JS and thus reduce the latency.
However I don't think Apple would allow the use of that kind of private APIs.
I tried WebSocket compression via [permessage-deflate](https://tools.ietf.org/id/draft-ietf-hybi-permessage-compression-19.txt) extension but it just makes everything slower.
The WebSocket protocol is perfectionnable and may be faster if frames are managed more efficiently.
The main bottleneck is not the computing power but the memory speed (that's why it's faster on iOS than macOS),
  the frames are memcpy'd multiple times (only one time by the WebSocketServer.m, and the rest by the kernel and WebKit)

## Example

On the native side:

- Swift :
```swift
let server = WebSocketCamera()
```
- Objective-C :
```objective-c
WebSocketCamera *camera = [WebSocketCamera.alloc init];
```
That's it, the server automatically starts and will start the camera when JavaScript asks for it.
If you do not ask for the camera via JavaScript it will not wake the CPU nor use any computing resources.


On the JS side :
```javascript
import {Camera, Resolution, Position} from 'jscamerakit'
  
const myCanvas = document.getElementById('canvas')
const camera = new Camera().setCanvas(myCanvas)
  
camera.start({
  position: Position.Back,
  resolution: Resolution.HD1280x720
}).then(() => {
  console.log('Camera started, switch to 1080p')
  
  return camera.changeResolution(Resolution.HD1920x1080)
}).then(() => {
  console.log('Switched to 1080p, using face camera')
  
  return camera.changePosition(Position.Front)
}).then(() => {
  console.log('Switched to front camera, taking selfie..')
  
  return camera.capturePhoto()
}).then(() => {
  console.log('Photo saved to CameraRoll')
})
```
