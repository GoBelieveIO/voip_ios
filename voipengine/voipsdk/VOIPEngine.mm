//
//  VOIPEngine.m
//  Face
//
//  Created by houxh on 15/3/8.
//  Copyright (c) 2015年 beetle. All rights reserved.
//
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#import "VOIPEngine.h"
#import "AVSendStream.h"
#import "AVReceiveStream.h"
#import "util.h"
#import "WebRTC.h"
#include "webrtc/voice_engine/include/voe_network.h"

#define VOIP_AUDIO 1
#define VOIP_VIDEO 2

#define VOIP_RTP 1
#define VOIP_RTCP 2

@interface VOIPData : NSObject
@property(nonatomic, assign)int64_t sender;
@property(nonatomic, assign)int64_t receiver;
@property(nonatomic, assign) int type;
@property(nonatomic, getter = isRTP) BOOL rtp;
@property(nonatomic) NSData *content;
@end

@implementation VOIPData

@end

@interface VOIPEngine()<VoiceTransport>
@property(nonatomic) NSDate *beginDate;
@property(nonatomic) BOOL isPeerConnected;
@property(strong, nonatomic) AudioSendStream *sendStream;
@property(strong, nonatomic) AudioReceiveStream *recvStream;

@property(nonatomic, assign)int udpFD;
@property(nonatomic, strong)dispatch_source_t readSource;

@end


@implementation VOIPEngine

-(void)listenVOIP {
    if (self.readSource) {
        return;
    }
    
    struct sockaddr_in addr;
    self.udpFD = socket(AF_INET,SOCK_DGRAM,0);
    bzero(&addr,sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr=htonl(INADDR_ANY);
    addr.sin_port=htons(self.voipPort);
    
    int one = 1;
    setsockopt(self.udpFD, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    
    bind(self.udpFD, (struct sockaddr *)&addr,sizeof(addr));
    
    voip_sock_nonblock(self.udpFD, 1);
    
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.readSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, self.udpFD, 0, queue);
    __weak VOIPEngine *wself = self;
    dispatch_source_set_event_handler(self.readSource, ^{
        [wself handleRead];
    });
    
    dispatch_resume(self.readSource);
}


-(void)handleRead {
    char buf[64*1024];
    struct sockaddr_in addr;
    socklen_t len = sizeof(addr);
    size_t n = recvfrom(self.udpFD, buf, 64*1024, 0, (struct sockaddr*)&addr, &len);
    if (n <= 0) {
        NSLog(@"recv udp error:%d, %s", errno, strerror(errno));
        [self closeUDP];
        [self listenVOIP];
        return;
    }
    
    if (n <= 16) {
        NSLog(@"invalid voip data length");
        return;
    }
    
    VOIPData *vdata = [[VOIPData alloc] init];
    char *p = buf;
    
    vdata.sender = voip_readInt64(p);
    p += 8;
    vdata.receiver = voip_readInt64(p);
    p += 8;
    vdata.type = *p++;
    if (*p == VOIP_RTP) {
        vdata.rtp = YES;
    } else if (*p == VOIP_RTCP) {
        vdata.rtp = NO;
    }
    p++;
    
    vdata.content = [NSData dataWithBytes:p length:n-18];
    
    int ip = ntohl(addr.sin_addr.s_addr);
    int port = ntohs(addr.sin_port);
    [self onVOIPData:vdata ip:ip port:port];

}

-(void)onVOIPData:(VOIPData*)data ip:(int)ip port:(int)port {
    if (data.sender != self.callee) {
        NSLog(@"skip data...");
        return;
    }
    if (self.recvStream == nil) {
        NSLog(@"skip data...");
        return;
    }
    int channel = self.recvStream.voiceChannel;
    
    const void *packet = [data.content bytes];
    NSInteger packet_length = [data.content length];
    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    if (!self.isPeerConnected && self.calleeIP == ip && self.calleePort == port) {
        self.isPeerConnected = YES;
        NSLog(@"peer connected");
    }
    
    if (data.isRTP) {
        if (data.type == VOIP_AUDIO) {
            NSLog(@"audio data:%zd content:%zd", packet_length, data.content.length);
            rtc.voe_network->ReceivedRTPPacket(channel, packet, packet_length);
        }
    } else {
        if (data.type == VOIP_AUDIO) {
            NSLog(@"audio rtcp data:%zd", packet_length);
            rtc.voe_network->ReceivedRTCPPacket(channel, packet, packet_length);
        }
    }
}



-(void)startStream:(BOOL)isHeadphone {
    if (self.sendStream || self.recvStream) return;
    
    self.sendStream = [[AudioSendStream alloc] init];
    self.sendStream.voiceTransport = self;
    [self.sendStream start];
    
    self.recvStream = [[AudioReceiveStream alloc] init];
    self.recvStream.voiceTransport = self;
    self.recvStream.isHeadphone = isHeadphone;
    self.recvStream.isLoudspeaker = NO;
    
    [self.recvStream start];
    
    [self listenVOIP];
    self.beginDate = [NSDate date];
}

-(void)stopStream {
    if (!self.sendStream && !self.recvStream) return;
    NSLog(@"stop stream");
    [self.sendStream stop];
    [self.recvStream stop];
    
    [self closeUDP];
}

-(void)closeUDP {
    if (self.readSource) {
        dispatch_source_set_cancel_handler(self.readSource, ^{
            NSLog(@"udp read source canceled");
        });
        dispatch_source_cancel(self.readSource);
        NSLog(@"close udp socket");
        close(self.udpFD);
        self.udpFD = -1;
        self.readSource = nil;
    }
}

-(BOOL)isP2P {
    if (self.calleeIP != 0) {
        return YES;
    }
    
    return NO;
}


-(BOOL)sendVOIPData:(VOIPData*)data ip:(int)ip port:(short)port {
    if (self.udpFD == -1) {
        return NO;
    }
    if (data.content.length > 60*1024) {
        return NO;
    }
    
    char buff[64*1024];
    char *p = buff;
    voip_writeInt64(data.sender, p);
    p += 8;
    voip_writeInt64(data.receiver, p);
    p += 8;
    
    *p++ = data.type;
    if (data.isRTP) {
        *p++ = VOIP_RTP;
    } else {
        *p++ = VOIP_RTCP;
    }
    
    const void *src = [data.content bytes];
    NSInteger len = [data.content length];
    
    memcpy(p, src, len);
    
    struct sockaddr_in addr;
    bzero(&addr, sizeof(addr));
    
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr=htonl(ip);
    addr.sin_port=htons(port);
    
    size_t r = sendto(self.udpFD, buff, len + 18, 0, (struct sockaddr*)&addr, sizeof(addr));
    if (r == -1) {
        NSLog(@"send voip data error:%s", strerror(errno));
    }
    return YES;
}

-(BOOL)sendVOIPDataToServer:(VOIPData*)data {
    if (self.serverIP.length == 0) {
        return NO;
    }
    int ip = inet_addr([self.serverIP UTF8String]);
    ip = ntohl(ip);
    return [self sendVOIPData:data ip:ip port:self.voipPort];
}


#pragma mark VoiceTransport
-(void)sendVOIPData:(VOIPData*)vData {
    
    BOOL isP2P = self.isP2P;
    //2s内还未接受到对端的数据，转而使用服务器中转
    if (isP2P && !self.isPeerConnected && [self.beginDate timeIntervalSinceNow]*1000 < -2000) {
        isP2P = NO;
    }
    
    BOOL r = NO;
    if (isP2P) {
        r = [self sendVOIPData:vData ip:self.calleeIP port:self.calleePort];
    } else {
        r = [self sendVOIPDataToServer:vData];
    }
    if (!r) {
        NSLog(@"send rtp data fail");
    }
}

-(int)sendRTPPacketA:(const void*)data length:(int)length {
    VOIPData *vData = [[VOIPData alloc] init];
    
    vData.sender = self.caller;
    vData.receiver = self.callee;
    vData.type = VOIP_AUDIO;
    vData.rtp = YES;
    vData.content = [NSData dataWithBytes:data length:length];
    //NSLog(@"send rtp package:%d", length);
    
    [self sendVOIPData:vData];
    return length;
}

-(int)sendRTCPPacketA:(const void*)data length:(int)length STOR:(BOOL)STOR {
    if (!STOR) {
        return 0;
    }
    
    //NSLog(@"send rtcp package:%d", length);
    VOIPData *vData = [[VOIPData alloc] init];
    
    vData.sender = self.caller;
    vData.receiver = self.callee;
    vData.rtp = NO;
    vData.type = VOIP_AUDIO;
    vData.content = [NSData dataWithBytes:data length:length];
    
    [self sendVOIPData:vData];
    return length;
}


@end
