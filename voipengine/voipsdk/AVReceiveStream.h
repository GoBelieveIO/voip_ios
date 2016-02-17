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
    class Transport;
}

@interface AVReceiveStream : NSObject {
    
}
@property (weak, nonatomic) VOIPRenderView *render;
@property (assign) uint64_t uid;
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property(assign, nonatomic) webrtc::Transport *transport;
@property (assign, nonatomic) int voiceChannel;
@property (nonatomic) int32_t localVideoSSRC;
@property (nonatomic) int32_t remoteVideoSSRC;

@property (nonatomic) int32_t localVoiceSSRC;
@property (nonatomic) int32_t remoteVoiceSSRC;

@property (nonatomic) int32_t rtxSSRC;

-(void)setCall:(void*)call;

-(BOOL)start;
-(BOOL)stop;
@end

