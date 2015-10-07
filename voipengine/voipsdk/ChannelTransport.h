/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/
#ifndef VOIP_CHANNEL_TRANSPORT_H
#define VOIP_CHANNEL_TRANSPORT_H

class VoiceChannelTransport:webrtc::Transport{
public:
    VoiceChannelTransport(webrtc::VoENetwork* voe_network, int channel,
                          id<VoiceTransport> transport, BOOL STOR): channel_(channel),
    voe_network_(voe_network),
    transport_(transport), STOR_(STOR){
        
        int registered = voe_network_->RegisterExternalTransport(channel_,
                                                                 *this);
        
        assert(registered == 0);
        
    }
    
    virtual ~VoiceChannelTransport() {
        voe_network_->DeRegisterExternalTransport(channel_);
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

#endif
