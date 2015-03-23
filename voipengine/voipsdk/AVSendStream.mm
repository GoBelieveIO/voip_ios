#import "AVSendStream.h"
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
#include <string>
#import "WebRTC.h"
//#include "channel_transport.h"
#include "ChannelTransport.h"

#define EXPECT_EQ(a, b) do {if ((a)!=(b)) assert(0);} while(0)
#define EXPECT_TRUE(a) do {BOOL c = (a); assert(c);} while(0)
#define EXPECT_NE(a, b) do {if ((a)==(b)) assert(0);} while(0)

#define DEFAULT_AUDIO_CODEC                             "ILBC"//"ISAC"


@interface AudioSendStream()
@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;
@end

@implementation AudioSendStream

- (void)dealloc
{
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
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

-(void)setSendVoiceCodec {
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

-(BOOL) start
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network,
                                                           self.voiceChannel,
                                                           self.voiceTransport, YES);
    NSLog(@"transport:0x%x", self.voiceChannelTransport);
    
    int error = 0;
    int audio_capture_device_index = 0;
    error = rtc.voe_hardware->SetRecordingDevice(audio_capture_device_index);
    
    [self setSendVoiceCodec];
    error = rtc.voe_apm->SetAgcStatus(true, webrtc::kAgcDefault);
    error = rtc.voe_apm->SetNsStatus(true, webrtc::kNsHighSuppression);
    

    [self startSend];
    [self startReceive];
    
    return YES;
}

-(BOOL)stop {
    WebRTC *rtc = [WebRTC sharedWebRTC];

    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    rtc.base->DisconnectAudioChannel(self.voiceChannel);
    return YES;
}

@end



@interface AVSendStream() 

@property(assign, nonatomic)VideoChannelTransport *channelTransport;
@property(assign, nonatomic)VoiceChannelTransport *voiceChannelTransport;

@property(assign, nonatomic) int captureId;
@property(assign, nonatomic)webrtc::VideoCaptureModule* captureModule;
@property(copy, nonatomic)NSString *deviceName;
@end

@implementation AVSendStream

- (void)dealloc
{
    NSAssert(self.channelTransport == NULL &&
             self.voiceChannelTransport == NULL &&
             self.captureModule == NULL, @"");
    NSLog(@"av send stream dealloc");
}

-(void)sendKeyFrame {
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.codec->SendKeyFrame(self.videoChannel);
}

- (void)startSend
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.base->StartSend(self.videoChannel);
    rtc.voe_base->StartSend(self.voiceChannel);
}

- (void)startReceive
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    rtc.base->StartReceive(self.videoChannel);
    rtc.voe_base->StartReceive(self.voiceChannel);
}
- (void)startCapture
{
    const unsigned int KMaxDeviceNameLength = 128;
    const unsigned int KMaxUniqueIdLength = 256;
    char deviceName[KMaxDeviceNameLength];
    memset(deviceName, 0, KMaxDeviceNameLength);
    char uniqueId[KMaxUniqueIdLength];
    memset(uniqueId, 0, KMaxUniqueIdLength);
    
    bool captureDeviceSet = false;
    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    webrtc::VideoCaptureModule::DeviceInfo* devInfo =
    webrtc::VideoCaptureFactory::CreateDeviceInfo(0);
    for (size_t captureIdx = 0;
         captureIdx < devInfo->NumberOfDevices();
         captureIdx++)
    {
        EXPECT_EQ(0, devInfo->GetDeviceName(captureIdx, deviceName,
                                            KMaxDeviceNameLength, uniqueId,
                                            KMaxUniqueIdLength));
        
        self.captureModule = webrtc::VideoCaptureFactory::Create(
                                                    captureIdx, uniqueId);
        if (self.captureModule == NULL)  // Failed to open this device. Try next.
        {
            continue;
        }
        self.captureModule->AddRef();
        
        int captureId;
        int error = rtc.capture->AllocateCaptureDevice(*self.captureModule, captureId);
        if (error == 0)
        {
            captureDeviceSet = true;
            self.captureId = captureId;
            break;
        }
    }
    delete devInfo;
    EXPECT_TRUE(captureDeviceSet);
    if (!captureDeviceSet) {
        return;
    }
    self.deviceName = [NSString stringWithUTF8String:deviceName];
    rtc.capture->SetRotateCapturedFrames(self.captureId, webrtc::RotateCapturedFrame_90);
    EXPECT_EQ(0, rtc.capture->StartCapture(self.captureId));
}

-(void)setSendVoiceCodec {
    int error;
    WebRTC *rtc = [WebRTC sharedWebRTC];
    EXPECT_TRUE(rtc.voe_codec->NumOfCodecs());
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

- (void)setSendVideoCodec {
    webrtc::VideoCodecType sendCodec = webrtc::kVideoCodecVP8 ;
    int width = 150;
    int height = 140;
    int frameRate = 30;
    int startBitrate = 300;
    
    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    webrtc::VideoCodec videoCodec;
    memset(&videoCodec, 0, sizeof(webrtc::VideoCodec));
    bool sendCodecSet = false;
    for (int idx = 0; idx < rtc.codec->NumberOfCodecs(); idx++) {
        EXPECT_EQ(0, rtc.codec->GetCodec(idx, videoCodec));
        videoCodec.width = width;
        videoCodec.height = height;
        videoCodec.maxFramerate = frameRate;
        
        if (videoCodec.codecType == sendCodec && sendCodecSet == false) {
            if (videoCodec.codecType != webrtc::kVideoCodecI420) {
                videoCodec.startBitrate = startBitrate;
                videoCodec.maxBitrate = startBitrate * 3;
            }
            EXPECT_EQ(0, rtc.codec->SetSendCodec(self.videoChannel, videoCodec));
            sendCodecSet = true;
        }
        if (videoCodec.codecType == webrtc::kVideoCodecVP8) {
            videoCodec.width = 352;
            videoCodec.height = 288;
        }
    }
    EXPECT_TRUE(sendCodecSet);
}

-(BOOL) start
{
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    self.voiceChannel = rtc.voe_base->CreateChannel();
    self.voiceChannelTransport = new VoiceChannelTransport(rtc.voe_network,
                                                           self.voiceChannel,
                                                           self.voiceTransport, YES);
    
    int error = 0;
    int audio_capture_device_index = 0;
    error = rtc.voe_hardware->SetRecordingDevice(audio_capture_device_index);
    
    [self setSendVoiceCodec];
    error = rtc.voe_apm->SetAgcStatus(true, webrtc::kAgcDefault);
    error = rtc.voe_apm->SetNsStatus(true, webrtc::kNsHighSuppression);
    
    
    int videoChannel;
    
    error = rtc.base->CreateChannel(videoChannel);
    if (error != 0) {
        return NO;
    }
    self.videoChannel = videoChannel;
    
    rtc.base->ConnectAudioChannel(videoChannel, self.voiceChannel);

    self.channelTransport = new VideoChannelTransport(rtc.network,
                                                      self.videoChannel,
                                                      self.videoTransport, YES);
    
    [self setSendVideoCodec];
    
    rtc.rtp_rtcp->SetRTCPStatus(videoChannel,
                                webrtc::kRtcpCompound_RFC4585);
    rtc.rtp_rtcp->SetKeyFrameRequestMethod(videoChannel,
                                           webrtc::kViEKeyFrameRequestPliRtcp);
    if (self.hasVideo) {
        [self startCapture];
    
        error = rtc.capture->ConnectCaptureDevice(self.captureId, self.videoChannel);
        if (error != 0) {
            return NO;
        }
    }
    
    [self startSend];
    [self startReceive];
    if (self.render) {
        webrtc::VideoRender* _vrm1;
        
        webrtc::VideoRenderType _renderType = webrtc::kRenderiOS;
        void *window1 = (__bridge void*)self.render;
        _vrm1 = webrtc::VideoRender::CreateVideoRender(4561, window1, false, _renderType);
        
        error = rtc.render->RegisterVideoRenderModule(*_vrm1);
        error = rtc.render->AddRenderer(self.captureId, window1, 0, 0.0, 0.0, 1.0, 1.0);
        error = rtc.render->StartRender(self.captureId);
        
        NSLog(@"\nCapture device is renderered in Window 1");
    }
    
    return YES;
}

-(BOOL)stop {
    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    rtc.voe_base->StopReceive(self.voiceChannel);
    rtc.voe_base->StopSend(self.voiceChannel);
    rtc.voe_base->DeleteChannel(self.voiceChannel);
    rtc.base->DisconnectAudioChannel(self.voiceChannel);
    delete self.voiceChannelTransport;
    self.voiceChannelTransport = NULL;
    rtc.base->StopReceive(self.videoChannel);
    rtc.base->StopSend(self.videoChannel);
    
    rtc.render->StopRender(self.captureId);
    rtc.render->RemoveRenderer(self.captureId);
    
    rtc.capture->StopCapture(self.captureId);
    rtc.capture->DisconnectCaptureDevice(self.videoChannel);
    rtc.capture->ReleaseCaptureDevice(self.captureId);
    
    int error = rtc.base->DeleteChannel(self.videoChannel);
    if (error != 0) {
        return NO;
    }
    
    delete self.channelTransport;
    self.channelTransport = NULL;
    if (self.captureModule) {
        self.captureModule->Release();
        self.captureModule = NULL;
    }
    return YES;
}


@end
