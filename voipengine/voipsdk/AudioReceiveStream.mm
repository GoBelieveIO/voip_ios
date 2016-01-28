/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#include "webrtc/voice_engine/include/voe_network.h"
#include "webrtc/voice_engine/include/voe_base.h"
#include "webrtc/voice_engine/include/voe_audio_processing.h"
#include "webrtc/voice_engine/include/voe_dtmf.h"
#include "webrtc/voice_engine/include/voe_codec.h"
#include "webrtc/voice_engine/include/voe_errors.h"
#include "webrtc/voice_engine/include/voe_neteq_stats.h"
#include "webrtc/voice_engine/include/voe_file.h"
#include "webrtc/voice_engine/include/voe_rtp_rtcp.h"
#include "webrtc/voice_engine/include/voe_hardware.h"

#import "AudioReceiveStream.h"
#import "WebRTC.h"
#include "ChannelTransport.h"

@interface AudioReceiveStream()
@property(assign, nonatomic) VoiceChannelTransport *voiceChannelTransport;
@end

@implementation AudioReceiveStream


- (void)dealloc {
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    NSLog(@"audio receive stream dealloc");
}


- (void)startReceive {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.voe_base->StartReceive(self.voiceChannel);
}

- (BOOL)start {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    
    //register external transport
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network, self.voiceChannel, self.voiceTransport, NO);
    
    
    [self startReceive];
    rtc.voe_base->StartPlayout(self.voiceChannel);
    
    return YES;
}

- (BOOL)stop {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    //deregister external transport
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->StopPlayout(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    
    return YES;
}

@end


