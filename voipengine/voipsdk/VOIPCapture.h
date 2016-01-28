/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#define WIDTH 640
#define HEIGHT 480
#define FPS 30

@protocol VOIPCaptureDelegate
-(void)onIncomingCapturedFrame:(void*)frame;
@end

@class VOIPRenderView;
@interface VOIPCapture : NSObject
@property(nonatomic, getter=isFrontCamera) BOOL frontCamera;
@property(nonatomic) VOIPRenderView *render;
@property(nonatomic, weak) id<VOIPCaptureDelegate> delegate;

-(BOOL)startCapture;
-(void)stopCapture;
-(void)switchCamera;
@end
