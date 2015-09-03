#ifndef AVRECEIVE_STREAM_H
#define AVRECEIVE_STREAM_H
//#include "webrtc/test/channel_transport/include/channel_transport.h"
#include "AVTransport.h"



class VideoChannelTransport;
class VoiceChannelTransport;


class AudioReceiveStream {
public:
  bool isHeadphone;
  int playoutDeviceIndex;
  VoiceTransport *voiceTransport;

private:
  bool isLoudspeaker;

  int voiceChannel;
  VoiceChannelTransport *voiceChannelTransport;


public:
	AudioReceiveStream();
    void start();
    void stop();

    int VoiceChannel() {
        return this->voiceChannel;
    }
private:
	void startSend();
	void startReceive();

};



#include "webrtc/modules/video_capture/include/video_capture_factory.h"
#include "webrtc/base/thread.h"
#include "webrtc/base/scoped_ptr.h"
#include "webrtc/base/asyncinvoker.h"
#include "webrtc/base/messagehandler.h"
#include "webrtc/base/bind.h"
#include "webrtc/base/helpers.h"
#include "webrtc/base/checks.h"
#include "webrtc/base/criticalsection.h"
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




class AVReceiveStream : public webrtc::VideoRenderer {
public:
  bool isHeadphone;
  int playoutDeviceIndex;
  VoiceTransport *voiceTransport;

private:
  bool isLoudspeaker;

  int voiceChannel;
  VoiceChannelTransport *voiceChannelTransport;


    webrtc::Call *call_;
    VideoRenderer *renderer_;
    webrtc::VideoReceiveStream *stream_;
    webrtc::AudioReceiveStream *audioStream_;
    webrtc::VideoDecoder *decoder_;

public:
	AVReceiveStream();
    void start();
    void stop();

    int VoiceChannel() {
        return this->voiceChannel;
    }

    //implement VideoRenderer
    virtual void RenderFrame(const webrtc::VideoFrame& video_frame,
                             int time_to_render_ms) ;
    virtual bool IsTextureSupported() const;

};

#endif
