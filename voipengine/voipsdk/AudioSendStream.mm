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

#import "AudioSendStream.h"
#import "WebRTC.h"
#include "ChannelTransport.h"

#define DEFAULT_AUDIO_CODEC                             "ILBC"//"ISAC"

@interface AudioSendStream()
@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;
@end

@implementation AudioSendStream

- (void)dealloc
{
    NSAssert(self.voiceChannelTransport == NULL, @"");
    NSLog(@"audio send stream dealloc");
}


- (void)startSend
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.voe_base->StartSend(self.voiceChannel);
}

- (void)startReceive
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.voe_base->StartReceive(self.voiceChannel);
}

- (void)setSendVoiceCodec {
    int error;
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.voe_codec->NumOfCodecs();
    webrtc::CodecInst audio_codec;
    memset(&audio_codec, 0, sizeof(webrtc::CodecInst));
    for (int codec_idx = 0; codec_idx < rtc.voe_codec->NumOfCodecs(); codec_idx++) {
        error = rtc.voe_codec->GetCodec(codec_idx, audio_codec);
        
        if (strcmp(audio_codec.plname, DEFAULT_AUDIO_CODEC) == 0) {
            break;
        }
    }
    
    error = rtc.voe_codec->SetSendCodec(self.voiceChannel, audio_codec);
    NSLog(@"codec:%s", audio_codec.plname);
}

- (BOOL)start
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    //register external transport
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network,
                                                           self.voiceChannel,
                                                           self.voiceTransport, YES);
    
    [self setSendVoiceCodec];
    
    
    [self startSend];
    [self startReceive];
    
    return YES;
}

- (BOOL)stop {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    //deregister external transport
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    
    
    return YES;
}

@end


