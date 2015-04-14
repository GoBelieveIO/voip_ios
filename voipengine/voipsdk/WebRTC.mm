/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#import "WebRTC.h"
#include "webrtc/voice_engine/include/voe_base.h"
#include "webrtc/common_types.h"
#include "webrtc/video_engine/include/vie_base.h"
#include "webrtc/video_engine/include/vie_capture.h"
#include "webrtc/video_engine/include/vie_codec.h"
#include "webrtc/video_engine/include/vie_image_process.h"
#include "webrtc/video_engine/include/vie_network.h"
#include "webrtc/video_engine/include/vie_render.h"
#include "webrtc/video_engine/include/vie_rtp_rtcp.h"
#include "webrtc/video_engine/vie_defines.h"
#include "webrtc/video_engine/include/vie_errors.h"
#include "webrtc/video_engine/include/vie_render.h"

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
        NSString *logfile = [NSString stringWithFormat:@"%@/trace.txt", NSTemporaryDirectory()];
        
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
        
        self.video_engine = webrtc::VideoEngine::Create();
        EXPECT_TRUE(self.video_engine != NULL);
        EXPECT_EQ(0, self.video_engine->SetTraceFile([logfile UTF8String]));
        EXPECT_EQ(0, self.video_engine->SetTraceFilter(webrtc::kTraceNone));
        
        
        webrtc::VideoEngine *video_engine = self.video_engine;
        
        self.base = webrtc::ViEBase::GetInterface(video_engine);
        EXPECT_TRUE(self.base != NULL);
        
        EXPECT_EQ(0, self.base->Init());
        
        self.base->SetVoiceEngine(self.voice_engine);
        
        self.capture = webrtc::ViECapture::GetInterface(video_engine);
        EXPECT_TRUE(self.capture != NULL);
        
        
        self.rtp_rtcp = webrtc::ViERTP_RTCP::GetInterface(video_engine);
        EXPECT_TRUE(self.rtp_rtcp != NULL);
        self.render = webrtc::ViERender::GetInterface(video_engine);
        EXPECT_TRUE(self.render != NULL);
        
        self.codec = webrtc::ViECodec::GetInterface(video_engine);
        EXPECT_TRUE(self.codec != NULL);
        
        self.network = webrtc::ViENetwork::GetInterface(video_engine);
        EXPECT_TRUE(self.network != NULL);
        
        self.image_process = webrtc::ViEImageProcess::GetInterface(video_engine);
        EXPECT_TRUE(self.image_process != NULL);
        
//        self.encryption = webrtc::ViEEncryption::GetInterface(video_engine);
//        EXPECT_TRUE(self.encryption != NULL);
    }
    return self;
}

-(void)dealloc {
//    EXPECT_EQ(0, self.encryption->Release());
//    self.encryption = NULL;
    EXPECT_EQ(0, self.image_process->Release());
    self.image_process = NULL;
    EXPECT_EQ(0, self.codec->Release());
    self.codec = NULL;
    EXPECT_EQ(0, self.capture->Release());
    self.capture = NULL;
    EXPECT_EQ(0, self.render->Release());
    self.render = NULL;
    EXPECT_EQ(0, self.rtp_rtcp->Release());
    self.rtp_rtcp = NULL;
    EXPECT_EQ(0, self.network->Release());
    self.network = NULL;
    EXPECT_EQ(0, self.base->Release());
    self.base = NULL;
    webrtc::VideoEngine *video_engine = self.video_engine;
    EXPECT_TRUE(webrtc::VideoEngine::Delete(video_engine));
    self.video_engine = NULL;
    
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