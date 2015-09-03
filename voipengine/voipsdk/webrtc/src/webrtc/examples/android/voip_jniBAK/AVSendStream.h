//#include "webrtc/test/channel_transport/include/channel_transport.h"
#include "AVTransport.h"

#include <string>

namespace webrtc {
class VideoCaptureModule;
}

class VideoChannelTransport;
class VoiceChannelTransport;


class AudioSendStream {
public:
  std::string codec;
  int recordDeviceIndex;
  VoiceTransport *voiceTransport;

public:
  AudioSendStream();
  void start();
  void stop();
  
  int VoiceChannel() {
    return this->voiceChannel;
  }

private:
  void startSend();
  void startReceive();

  void setSendVoiceCodec();
  void setSendVideoCodec();
  void startCapture();

private:
  int voiceChannel;

  VoiceChannelTransport *voiceChannelTransport;
};

#include "webrtc/common_types.h"
#include "webrtc/modules/video_capture/include/video_capture.h"

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




namespace webrtc {
    class VideoCaptureModule;
}

class WebRtcVcmFactory;

class AVSendStream : public webrtc::VideoCaptureDataCallback {
public:
  std::string codec;
  int recordDeviceIndex;
  VoiceTransport *voiceTransport;

public:
  AVSendStream();
  void start();
  void stop();
  
  int VoiceChannel() {
    return this->voiceChannel;
  }

  //implement VideoCaptureDataCallback
  virtual void OnIncomingCapturedFrame(const int32_t id,
                                       const webrtc::VideoFrame& videoFrame);
  virtual void OnCaptureDelayChanged(const int32_t id,
                                     const int32_t delay);
private:
  void startSend();
  void startReceive();

  void setSendVoiceCodec();
  void setSendVideoCodec();
  void startCapture();

  void startSendStream();

private:

union VideoEncoderSettings {
   webrtc::VideoCodecVP8 vp8;
   webrtc::VideoCodecVP9 vp9;
};

private:
  int voiceChannel;

  VoiceChannelTransport *voiceChannelTransport;

    WebRtcVcmFactory *factory_;
    webrtc::VideoCaptureModule* module_;

    int captured_frames_;
    std::vector<uint8_t> capture_buffer_;
    
    webrtc::Call *call_;
    VideoEncoderSettings encoder_settings_;
    
    webrtc::VideoSendStream *stream_;
    webrtc::VideoEncoder *encoder_;
};


