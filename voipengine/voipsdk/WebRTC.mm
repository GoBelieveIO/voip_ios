/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#import "WebRTC.h"

#include "webrtc/common_types.h"
#include "webrtc/system_wrappers/interface/field_trial_default.h"
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


#include "webrtc/engine_configurations.h"
#include "webrtc/modules/video_render/include/video_render_defines.h"
#include "webrtc/modules/video_render/include/video_render.h"
#include "webrtc/modules/video_capture/include/video_capture_factory.h"
#include "webrtc/system_wrappers/interface/tick_util.h"

#define EXPECT_EQ(a, b) do {if ((a)!=(b)) assert(0);} while(0)
#define EXPECT_TRUE(a) do {BOOL c = (a); assert(c);} while(0)
#define EXPECT_NE(a, b) do {if ((a)==(b)) assert(0);} while(0)

@implementation WebRTC
+ (WebRTC *)sharedWebRTC {
    static id webrtc_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!webrtc_instance) {
            webrtc_instance = [[WebRTC alloc] init];
        }
    });
    return webrtc_instance;
}

-(id)init {
    self = [super init];
    if (self) {
        int error = 0;
        
        webrtc::VoiceEngine* voe = webrtc::VoiceEngine::Create();
        self.voice_engine = voe;
        
        self.voe_base = webrtc::VoEBase::GetInterface(voe);
        
        error = self.voe_base->Init();
        EXPECT_EQ(0, error);
        
        self.voe_codec = webrtc::VoECodec::GetInterface(voe);
        
        
        self.voe_hardware = webrtc::VoEHardware::GetInterface(voe);
        
        
        self.voe_network = webrtc::VoENetwork::GetInterface(voe);
        
        
        self.voe_apm = webrtc::VoEAudioProcessing::GetInterface(voe);
        
        self.voe_rtp_rtcp = webrtc::VoERTP_RTCP::GetInterface(voe);
        
         webrtc::field_trial::InitFieldTrialsFromString("");

    }
    return self;
}

-(void)dealloc {
    self.voe_base->Release();
    self.voe_codec->Release();
    self.voe_hardware->Release();
    self.voe_network->Release();
    self.voe_apm->Release();
    
    webrtc::VoiceEngine *voice_engine = self.voice_engine;
    webrtc::VoiceEngine::Delete(voice_engine);
    self.voice_engine = NULL;
}
@end