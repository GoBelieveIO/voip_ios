#import "AVReceiveStream.h"
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
#include "ChannelTransport.h"


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
    
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network, self.voiceChannel, self.voiceTransport, NO);
    
    int error;
    int audio_playback_device_index = 0;
    error = rtc.voe_hardware->SetPlayoutDevice(audio_playback_device_index);
    
    rtc.voe_apm->SetAgcStatus(true);
    rtc.voe_apm->SetNsStatus(true);
    if (!self.isHeadphone) {
        rtc.voe_apm->SetEcStatus(true);
    }

    [self startReceive];
    rtc.voe_base->StartPlayout(self.voiceChannel);
    if (self.isLoudspeaker) {
        error = rtc.voe_hardware->SetLoudspeakerStatus(true);
    }
    return YES;
}

- (BOOL)stop {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->StopPlayout(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    rtc.base->DisconnectAudioChannel(self.voiceChannel);


    return YES;
}

@end

@interface AVReceiveStream()
@property(assign, nonatomic)VideoChannelTransport *channelTransport;
@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;

@end

@implementation AVReceiveStream

- (void)dealloc {
    NSAssert(self.channelTransport == NULL &&
             self.voiceChannelTransport == NULL, @"");
}


- (void)startReceive
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.base->StartReceive(self.videoChannel);
    rtc.voe_base->StartReceive(self.voiceChannel);
   
}

-(BOOL)start
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network, self.voiceChannel, self.voiceTransport, NO);
    
    int error;
    int audio_playback_device_index = 0;
    error = rtc.voe_hardware->SetPlayoutDevice(audio_playback_device_index);
 
    rtc.voe_apm->SetAgcStatus(true);
    rtc.voe_apm->SetNsStatus(true);
    if (!self.isHeadphone) {
        rtc.voe_apm->SetEcStatus(true);
    }
    int videoChannel;
    error = rtc.base->CreateChannel(videoChannel);
    self.videoChannel = videoChannel;
    
    rtc.base->ConnectAudioChannel(self.videoChannel, self.voiceChannel);
    
    
    self.channelTransport = new VideoChannelTransport(rtc.network, videoChannel, self.videoTransport, NO);
    
    rtc.rtp_rtcp->SetRTCPStatus(videoChannel,
                                webrtc::kRtcpCompound_RFC4585);
    rtc.rtp_rtcp->SetKeyFrameRequestMethod(videoChannel,
                                           webrtc::kViEKeyFrameRequestPliRtcp);
    

    if (self.render) {
        void *window = (__bridge void*)self.render;
        error = rtc.render->AddRenderer(self.videoChannel, window, 1, 0.0, 0.0, 1.0, 1.0);
    }

    [self startReceive];
    
    rtc.voe_base->StartPlayout(self.voiceChannel);
    error = rtc.render->StartRender(self.videoChannel);
    if (self.isLoudspeaker) {
        error = rtc.voe_hardware->SetLoudspeakerStatus(true);
    }
    return YES;
}

- (BOOL)stop {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->StopPlayout(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    rtc.base->DisconnectAudioChannel(self.voiceChannel);
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    
  
    rtc.base->StopReceive(self.videoChannel);
    rtc.base->StopSend(self.videoChannel);

    rtc.render->StopRender(self.videoChannel);
    rtc.render->RemoveRenderer(self.videoChannel);
    
    int error = rtc.base->DeleteChannel(self.videoChannel);
    if (error) {
        return NO;
    }
    delete self.channelTransport;
    self.channelTransport = NULL;
    return YES;
}

@end
