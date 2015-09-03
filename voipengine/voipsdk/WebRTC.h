#include <Foundation/Foundation.h>




namespace webrtc {
    class VideoEngine;
    class ViEBase;
    class ViECapture;
    class ViERender;
    class ViERTP_RTCP;
    class ViECodec;
    class ViENetwork;
    class ViEImageProcess;
    class ViEEncryption;
    class VoiceEngine;
    class VoEBase;
    class VoECodec;
    class VoEHardware;
    class VoENetwork;
    class VoEAudioProcessing;
}
@interface WebRTC : NSObject
@property(assign, nonatomic)webrtc::VideoEngine* video_engine;
@property(assign, nonatomic)webrtc::ViEBase* base;
@property(assign, nonatomic)webrtc::ViECapture* capture;
@property(assign, nonatomic)webrtc::ViERender* render;
@property(assign, nonatomic)webrtc::ViERTP_RTCP* rtp_rtcp;
@property(assign, nonatomic)webrtc::ViECodec* codec;
@property(assign, nonatomic)webrtc::ViENetwork* network;
@property(assign, nonatomic)webrtc::ViEImageProcess* image_process;
@property(assign, nonatomic)webrtc::ViEEncryption* encryption;


@property(assign, nonatomic)webrtc::VoiceEngine *voice_engine;
@property(assign, nonatomic)webrtc::VoEBase* voe_base;
@property(assign, nonatomic)webrtc::VoECodec* voe_codec;
@property(assign, nonatomic)webrtc::VoEHardware* voe_hardware;
@property(assign, nonatomic)webrtc::VoENetwork* voe_network;
@property(assign, nonatomic)webrtc::VoEAudioProcessing* voe_apm;

+ (WebRTC *)sharedWebRTC;
@end