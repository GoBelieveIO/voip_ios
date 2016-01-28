/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/
#include <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVTransport.h"


@class VOIPRenderView;

namespace webrtc {
    class VideoFrame;
}

@interface AVSendStream : NSObject {
}

@property(weak, nonatomic) id<VoiceTransport> voiceTransport;
@property(assign, nonatomic) int voiceChannel;

@property(nonatomic) int32_t videoSSRC;
@property(nonatomic) int32_t voiceSSRC;

@property(nonatomic) int32_t rtxSSRC;

- (void)OnIncomingCapturedFrame:(int32_t)id frame:(const webrtc::VideoFrame*)frame ;
-(void)setCall:(void*)call;
-(void)sendKeyFrame;
-(BOOL)start;
-(BOOL)stop;
@end

