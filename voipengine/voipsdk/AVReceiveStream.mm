/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#import "AVReceiveStream.h"
#import "WebRTC.h"

#include "webrtc/modules/video_capture/include/video_capture_factory.h"
#include "webrtc/base/thread.h"
#include "webrtc/base/scoped_ptr.h"
#include "webrtc/base/asyncinvoker.h"
#include "webrtc/base/messagehandler.h"
#include "webrtc/base/bind.h"
#include "webrtc/base/helpers.h"
#include "webrtc/base/checks.h"
#include "webrtc/base/criticalsection.h"
#include "webrtc/base/logging.h"
#include "webrtc/base/safe_conversions.h"
#include "webrtc/base/thread.h"
#include "webrtc/base/timeutils.h"
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
#include "ChannelTransport.h"
#import "VOIPRenderView.h"

#import "RTCI420Frame+Internal.h"
#import "RTCI420Frame.h"
#import "RTCEAGLVideoView.h"


const char kVp8CodecName[] = "VP8";
const char kVp9CodecName[] = "VP9";
const char kH264CodecName[] = "H264";

const int kDefaultVp8PlType = 100;
const int kDefaultVp9PlType = 101;
const int kDefaultH264PlType = 107;
const int kDefaultRedPlType = 116;
const int kDefaultUlpfecType = 117;
const int kDefaultRtxVp8PlType = 96;

static const int kNackHistoryMs = 1000;


@interface AudioReceiveStream()
@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;
@end

@implementation AudioReceiveStream


- (void)dealloc {
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    NSLog(@"audio receive stream dealloc");
}


- (void)startReceive
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.voe_base->StartReceive(self.voiceChannel);
    
}

-(BOOL)start
{
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

class VideoRenderer;
@interface AVReceiveStream() {
    webrtc::Call *call_;
    VideoRenderer *renderer_;
    webrtc::VideoReceiveStream *stream_;
    webrtc::AudioReceiveStream *audioStream_;
    webrtc::VideoDecoder *decoder_;
}

@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;

-(void)renderFrame:(const webrtc::VideoFrame&) video_frame render_ts:(int)time_to_render_ms;
@end



class VideoRenderer:public webrtc::VideoRenderer {
public:
    VideoRenderer(AVReceiveStream *s):s_(s) {}
    
    virtual void RenderFrame(const webrtc::VideoFrame& video_frame,
                             int time_to_render_ms) {
//        NSLog(@"render frame:%d %d rotation:%d", video_frame.width(), video_frame.height(), video_frame.rotation());
        [s_ renderFrame:video_frame render_ts:time_to_render_ms];
    }
    
    virtual bool IsTextureSupported() const {
        return true;
    }
    
private:
    __weak AVReceiveStream *s_;
};


@implementation AVReceiveStream

-(id)init {
    self = [super init];
    if (self) {
        renderer_ = new VideoRenderer(self);
        
    }
    return self;
}

-(void)dealloc {
    delete renderer_;
}

-(void)setCall:(void*)call {
    call_ = (webrtc::Call*)call;
}

-(BOOL)start {
    webrtc::VideoReceiveStream::Config config;

    webrtc::VideoCodecType type;
    const char *codec_name;
    int pl_type;
    type = webrtc::kVideoCodecVP8;
    codec_name = kVp8CodecName;
    pl_type = kDefaultVp8PlType;

    webrtc::VideoDecoder *video_decoder = NULL;
    
    if (type == webrtc::kVideoCodecVP8) {
        video_decoder = webrtc::VideoDecoder::Create(webrtc::VideoDecoder::kVp8);
    } else if (type == webrtc::kVideoCodecVP9) {
       video_decoder = webrtc::VideoDecoder::Create(webrtc::VideoDecoder::kVp9);
    } else if (type == webrtc::kVideoCodecH264) {
       video_decoder = webrtc::VideoDecoder::Create(webrtc::VideoDecoder::kH264);
    }
  
    
    webrtc::VideoReceiveStream::Decoder decoder;
    decoder.decoder = video_decoder;
    decoder.payload_type = pl_type;
    decoder.payload_name = codec_name;
    config.decoders.push_back(decoder);

    config.rtp.local_ssrc = self.localVideoSSRC;
    config.rtp.remote_ssrc = self.remoteVideoSSRC;
    config.rtp.nack.rtp_history_ms = kNackHistoryMs;
    config.rtp.fec.ulpfec_payload_type = kDefaultUlpfecType;
    config.rtp.fec.red_payload_type = kDefaultRedPlType;
    config.rtp.fec.red_rtx_payload_type = kDefaultRtxVp8PlType;
    

    webrtc::VideoReceiveStream::Config::Rtp::Rtx rtx;
    rtx.ssrc = self.rtxSSRC;
    rtx.payload_type = kDefaultRtxVp8PlType;
    config.rtp.rtx[kDefaultVp8PlType] = rtx;
    
    
//    config.sync_group = "sync";
    config.renderer = renderer_;
    
    webrtc::VideoReceiveStream *stream = call_->CreateVideoReceiveStream(config);
    stream->Start();
    
    stream_ = stream;
    decoder_ = video_decoder;
    
    [self startAudioStream];


    return YES;
}

-(void)startAudioStream {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network, self.voiceChannel, self.voiceTransport, NO);
    

    rtc.voe_rtp_rtcp->SetLocalSSRC(self.voiceChannel, self.localVoiceSSRC);
    
    rtc.voe_base->StartReceive(self.voiceChannel);
    rtc.voe_base->StartPlayout(self.voiceChannel);
}

-(BOOL)stop {
    if (stream_ == NULL) {
        return NO;
    }
    //video
    stream_->Stop();
    call_->DestroyVideoReceiveStream(stream_);
    stream_ = NULL;
    
    delete decoder_;
    decoder_ = NULL;


    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopPlayout(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);

    return YES;
}

-(void)renderFrame:(const webrtc::VideoFrame&) frame render_ts:(int)time_to_render_ms {
    RTCEAGLVideoView *rtcView = (__bridge RTCEAGLVideoView*)[self.render getRTCView];

    RTCI420Frame *f = [[RTCI420Frame alloc] initWithVideoFrame:&frame];

    [rtcView renderFrame:f];
    
}
@end
