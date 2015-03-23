#ifndef VOIP_CHANNEL_TRANSPORT_H
#define VOIP_CHANNEL_TRANSPORT_H

class VoiceChannelTransport:webrtc::Transport{
public:
    VoiceChannelTransport(webrtc::VoENetwork* voe_network, int channel,
                          id<VoiceTransport> transport, BOOL STOR): channel_(channel),
    voe_network_(voe_network),
    transport_(transport), STOR_(STOR){
        
        int registered = voe_network_->RegisterExternalTransport(channel,
                                                                 *this);
        
        assert(registered == 0);
        
    }
    
    virtual ~VoiceChannelTransport() {
        transport_ = nil;
    }
    
public:
    virtual int SendPacket(int channel, const void *data, size_t len) {
        return [transport_ sendRTPPacketA:data length:(int)len];
    }
    virtual int SendRTCPPacket(int channel, const void *data, size_t len){
        return [transport_ sendRTCPPacketA:data length:(int)len STOR:STOR_];
    }

private:
    int channel_;
    webrtc::VoENetwork* voe_network_;
    __weak id<VoiceTransport> transport_;
    BOOL STOR_;
};



class VideoChannelTransport:webrtc::Transport{
public:
    VideoChannelTransport(webrtc::ViENetwork* vie_network, int channel,
                          id<VideoTransport> transport, BOOL STOR): channel_(channel),
    vie_network_(vie_network),
    transport_(transport), STOR_(STOR){
        
        
        int registered = vie_network_->RegisterSendTransport(channel,
                                                             *this);
        
        assert(registered == 0);
    }
    virtual ~VideoChannelTransport() {
        transport_ = nil;
    }
    
public:
    virtual int SendPacket(int channel, const void *data, size_t len) {
        return [transport_ sendRTPPacketV:data length:(int)len];
    }
    virtual int SendRTCPPacket(int channel, const void *data, size_t len) {
        return [transport_ sendRTCPPacketV:data length:(int)len STOR:STOR_];
    }
private:
    int channel_;
    webrtc::ViENetwork* vie_network_;
    __weak id<VideoTransport> transport_;
    BOOL STOR_;
};


#endif