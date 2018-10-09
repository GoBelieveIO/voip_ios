/*
 *  Copyright 2017 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include <WebRTC/RTCCameraVideoCapturer.h>
// Controls the camera. Handles starting the capture, switching cameras etc.
@interface ARDCaptureController : NSObject

@property(nonatomic, assign) int width;
@property(nonatomic, assign) int height;
@property(nonatomic, assign) int fps;

- (instancetype)initWithCapturer:(RTCCameraVideoCapturer *)capturer
                            with:(int)width height:(int)height fps:(int)fps;
- (void)startCapture;
- (void)stopCapture;
- (void)switchCamera;

@end
