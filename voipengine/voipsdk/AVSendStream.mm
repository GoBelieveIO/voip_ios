/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#import "AVSendStream.h"
#import <AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>

#include <string>
#include "webrtc/common_types.h"

#include "webrtc/modules/video_capture/include/video_capture_factory.h"
#include "webrtc/common_video/libyuv/include/webrtc_libyuv.h"
#include "webrtc/modules/video_capture/include/video_capture.h"
#include "webrtc/video/audio_receive_stream.h"
#include "webrtc/video/video_receive_stream.h"
#include "webrtc/video/video_send_stream.h"
#include "webrtc/video_engine/vie_channel_group.h"
#include "webrtc/modules/utility/interface/process_thread.h"
#include "webrtc/modules/video_coding/codecs/h264/include/h264.h"

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
#include "webrtc/video_engine/vie_encoder.h"

#include "ChannelTransport.h"

#import "WebRTC.h"
#import "VOIPRenderView.h"
#import "RTCI420Frame+Internal.h"
#import "RTCI420Frame.h"
#import "RTCEAGLVideoView.h"

#define EXPECT_EQ(a, b) do {if ((a)!=(b)) assert(0);} while(0)
#define EXPECT_TRUE(a) do {BOOL c = (a); assert(c);} while(0)
#define EXPECT_NE(a, b) do {if ((a)==(b)) assert(0);} while(0)

#define DEFAULT_AUDIO_CODEC                             "ILBC"//"ISAC"


const char kVp8CodecName[] = "VP8";
const char kVp9CodecName[] = "VP9";
const char kH264CodecName[] = "H264";

const int kDefaultVp8PlType = 100;
const int kDefaultVp9PlType = 101;
const int kDefaultH264PlType = 107;
const int kDefaultRedPlType = 116;
const int kDefaultUlpfecType = 117;
const int kDefaultRtxVp8PlType = 96;



const int kMinVideoBitrate = 30;
const int kStartVideoBitrate = 300;
const int kMaxVideoBitrate = 1000;

const int kMinBandwidthBps = 30000;
const int kStartBandwidthBps = 300000;
const int kMaxBandwidthBps = 2000000;


const int kDefaultVideoMaxFramerate = 30;

static const int kDefaultQpMax = 56;

const char kCodecParamMaxBitrate[] = "x-google-max-bitrate";

static const int kNackHistoryMs = 1000;

#define STREAM_WIDTH 480
#define STREAM_HEIGHT 640

union VideoEncoderSettings {
    webrtc::VideoCodecVP8 vp8;
    webrtc::VideoCodecVP9 vp9;
};

@interface AVSendStream() {
    std::vector<uint8_t> capture_buffer_;
    
    webrtc::Call *call_;
    VideoEncoderSettings encoder_settings_;
    
    webrtc::VideoSendStream *stream_;
    webrtc::VideoEncoder *encoder_;
    
}

@property(assign, nonatomic) VoiceChannelTransport *voiceChannelTransport;

-(void)OnIncomingCapturedFrame:(int32_t)id frame:(const webrtc::VideoFrame*)frame;
@end



@implementation AVSendStream
- (id)init {
    self = [super init];
    if (self) {
 
        
    }
    return self;
}

- (void)dealloc {

}

- (void)setCall:(void*)call {
    call_ = (webrtc::Call*)call;
}

- (void)OnIncomingCapturedFrame:(int32_t)id frame:(const webrtc::VideoFrame*)frame {
    if (stream_) {
        webrtc::VideoCaptureInput *input = stream_->Input();
        input->IncomingCapturedFrame(*frame);
    }
}

-(void)sendKeyFrame {
    if (stream_) {
        stream_->encoder()->SendKeyFrame();
    }
}

- (BOOL)start {
    [self startSendStream];
    [self startAudioStream];
    return YES;
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


- (void)startAudioStream {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network,
                                                           self.voiceChannel,
                                                           self.voiceTransport, YES);
    
    [self setSendVoiceCodec];
    

    rtc.voe_rtp_rtcp->SetLocalSSRC(self.voiceChannel, self.voiceSSRC);
    rtc.voe_base->StartSend(self.voiceChannel);
}

- (std::vector<webrtc::VideoStream>) CreateVideoStreams {
    int max_bitrate_bps = kMaxVideoBitrate * 1000;
    
    webrtc::VideoStream stream;
    stream.width = STREAM_WIDTH;
    stream.height = STREAM_HEIGHT;
    stream.max_framerate = 30;
    
    stream.min_bitrate_bps = kMinVideoBitrate * 1000;
    stream.target_bitrate_bps = stream.max_bitrate_bps = max_bitrate_bps;
    
    int max_qp = kDefaultQpMax;
    stream.max_qp = max_qp;
    std::vector<webrtc::VideoStream> streams;
    streams.push_back(stream);
    return streams;
}


- (webrtc::VideoEncoderConfig)CreateVideoEncoderConfig {
    webrtc::VideoEncoderConfig encoder_config;

    encoder_config.min_transmit_bitrate_bps = 0;
    encoder_config.content_type = webrtc::VideoEncoderConfig::ContentType::kRealtimeVideo;

    encoder_config.streams = [self CreateVideoStreams];
    return encoder_config;
}

- (void*)ConfigureVideoEncoderSettings:(webrtc::VideoCodecType)type {
    if (type == webrtc::kVideoCodecVP8) {
        encoder_settings_.vp8 = webrtc::VideoEncoder::GetDefaultVp8Settings();
        encoder_settings_.vp8.automaticResizeOn = true;
        encoder_settings_.vp8.denoisingOn = false;
        encoder_settings_.vp8.frameDroppingOn = true;
        return &encoder_settings_.vp8;
    }
    if (type == webrtc::kVideoCodecVP9) {
        encoder_settings_.vp9 = webrtc::VideoEncoder::GetDefaultVp9Settings();
        encoder_settings_.vp9.denoisingOn = false;
        encoder_settings_.vp9.frameDroppingOn = true;
        return &encoder_settings_.vp9;
    }
    return NULL;
}


- (void)startSendStream {
    NSLog(@"support h264:%d", webrtc::H264Encoder::IsSupported());
    
    struct webrtc::VideoEncoderConfig encoder_config = [self CreateVideoEncoderConfig];
    if (encoder_config.streams.empty())
        return;
                                                                        
    webrtc::VideoEncoder *encoder = NULL;
    
    webrtc::VideoCodecType type;
    const char *codec_name;
    int pl_type;
    type = webrtc::kVideoCodecVP8;
    codec_name = kVp8CodecName;
    pl_type = kDefaultVp8PlType;
    
    if (type == webrtc::kVideoCodecVP8) {
        encoder = webrtc::VideoEncoder::Create(webrtc::VideoEncoder::kVp8);
    } else if (type == webrtc::kVideoCodecVP9) {
        encoder = webrtc::VideoEncoder::Create(webrtc::VideoEncoder::kVp9);
    } else if (type == webrtc::kVideoCodecH264) {
        encoder = webrtc::VideoEncoder::Create(webrtc::VideoEncoder::kH264);
    }

    webrtc::internal::VideoSendStream::Config config;

    config.encoder_settings.encoder = encoder;
    config.encoder_settings.payload_name = codec_name;
    config.encoder_settings.payload_type = pl_type;

    config.rtp.ssrcs.push_back(self.videoSSRC);
    config.rtp.nack.rtp_history_ms = kNackHistoryMs;
    config.rtp.fec.ulpfec_payload_type = kDefaultUlpfecType;
    config.rtp.fec.red_payload_type = kDefaultRedPlType;
    config.rtp.fec.red_rtx_payload_type = kDefaultRtxVp8PlType;
    
    config.rtp.rtx.payload_type = kDefaultRtxVp8PlType;
    config.rtp.rtx.ssrcs.push_back(self.rtxSSRC);
    
    encoder_config.encoder_specific_settings = [self ConfigureVideoEncoderSettings:type];
    webrtc::VideoSendStream *stream = call_->CreateVideoSendStream(config, encoder_config);
    encoder_config.encoder_specific_settings = NULL;
    stream->Start();
    stream_ = stream;
    encoder_ = encoder;
}


- (BOOL)stop {
    if (stream_ == NULL) {
        return YES;
    }

    stream_->Stop();
    call_->DestroyVideoSendStream(stream_);
    stream_ = NULL;
    
    delete encoder_;
    encoder_ = NULL;

    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);

    
    return YES;
}
@end

