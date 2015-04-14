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

@interface AudioReceiveStream : NSObject
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property(assign, nonatomic)int voiceChannel;

@property (assign, nonatomic) BOOL isHeadphone;
@property (assign, nonatomic) BOOL isLoudspeaker;


-(BOOL)start;
-(BOOL)stop;
@end

@interface AVReceiveStream : NSObject {
    
}
@property (weak, nonatomic) UIView *render;
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property (weak, nonatomic) id<VideoTransport> videoTransport;
@property(assign, nonatomic)int voiceChannel;
@property(assign, nonatomic)int videoChannel;
@property (assign) uint64_t uid;

@property (assign, nonatomic) BOOL isHeadphone;
@property (assign, nonatomic) BOOL isLoudspeaker;


-(BOOL)start;
-(BOOL)stop;
@end

