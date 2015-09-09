#include <Foundation/Foundation.h>




namespace webrtc {
    class VoiceEngine;
    class VoEBase;
    class VoECodec;
    class VoEHardware;
    class VoENetwork;
    class VoEAudioProcessing;
    class VoERTP_RTCP;
}
@interface WebRTC : NSObject


@property(assign, nonatomic)webrtc::VoiceEngine *voice_engine;
@property(assign, nonatomic)webrtc::VoEBase* voe_base;
@property(assign, nonatomic)webrtc::VoECodec* voe_codec;
@property(assign, nonatomic)webrtc::VoEHardware* voe_hardware;
@property(assign, nonatomic)webrtc::VoENetwork* voe_network;
@property(assign, nonatomic)webrtc::VoEAudioProcessing* voe_apm;
@property(assign, nonatomic)webrtc::VoERTP_RTCP *voe_rtp_rtcp;

+ (WebRTC *)sharedWebRTC;
@end