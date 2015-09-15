/*
 Copyright (c) 2014-2015, GoBelieve
 All rights reserved.
 
 This source code is licensed under the BSD-style license found in the
 LICENSE file in the root directory of this source tree. An additional grant
 of patent rights can be found in the PATENTS file in the same directory.
 */
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/time.h>
#import "VOIPEngine.h"
#import "AVSendStream.h"
#import "AVReceiveStream.h"
#import "util.h"
#import "WebRTC.h"
#include "webrtc/voice_engine/include/voe_network.h"
#include "webrtc/voice_engine/include/voe_audio_processing.h"
#include "webrtc/voice_engine/include/voe_hardware.h"

#include "webrtc/call.h"

#include <pthread.h>
//兼容没有消息头的旧版本协议
#define COMPATIBLE


#define VOIP_AUDIO 1
#define VOIP_VIDEO 2

#define VOIP_RTP 1
#define VOIP_RTCP 2


#define VOIP_AUTH 1
#define VOIP_AUTH_STATUS 2
#define VOIP_DATA 3

const int kMinVideoBitrate = 30;
const int kStartVideoBitrate = 300;
const int kMaxVideoBitrate = 2000;

const int kMinBandwidthBps = 30000;
const int kStartBandwidthBps = 300000;
const int kMaxBandwidthBps = 2000000;


@interface VOIPData : NSObject
@property(nonatomic, assign)int64_t sender;
@property(nonatomic, assign)int64_t receiver;
@property(nonatomic, assign) int type;
@property(nonatomic, getter = isRTP) BOOL rtp;
@property(nonatomic) NSData *content;
@end

@implementation VOIPData

@end


class AVEngine;

@interface VOIPEngine()<VoiceTransport> {
    webrtc::Call *call_;
    AVEngine *engine_;
    pthread_t thread_;
    
    pthread_t deliverThread_;
    pthread_mutex_t mutex_;
    pthread_cond_t cond_;
}
@property(nonatomic) NSDate *beginDate;
@property(nonatomic) BOOL isPeerConnected;

@property(strong, nonatomic) AudioSendStream *audioSendStream;
@property(strong, nonatomic) AudioReceiveStream *audioRecvStream;

@property(strong, nonatomic) AVSendStream *sendStream;
@property(strong, nonatomic) AVReceiveStream *recvStream;

@property(nonatomic) NSMutableArray *packets;

@property(atomic, assign) BOOL running;
@property(nonatomic, assign)int udpFD;
@property(nonatomic, strong)dispatch_source_t readSource;
@property(nonatomic, getter=isAuth) BOOL auth;
@property(nonatomic) BOOL isPeerNoHeader;

-(BOOL)sendVideoRTP:(const void*)data length:(size_t)len;

-(BOOL)sendVideoRTCP:(const void*)data length:(size_t)len;

-(void)recvLoop;
-(void)deliverLoop;
@end


static void* recv_thread(void *arg) {
    pthread_setname_np("recv thread");
    VOIPEngine *engine = (__bridge VOIPEngine*)arg;
    [engine recvLoop];
    NSLog(@"recv thread exit...");
    return NULL;
}

static void* deliver_thread(void *arg) {
    pthread_setname_np("deliver thread");
    VOIPEngine *engine = (__bridge VOIPEngine*)arg;
    [engine deliverLoop];
    return NULL;
}

class AVEngine : public webrtc::newapi::Transport, public webrtc::LoadObserver {
public:
    AVEngine(VOIPEngine *e):e_(e) {}
    
    virtual bool SendRtp(const uint8_t* data, size_t len) {
//        NSLog(@"send rtp:%ld", len);
        return [e_ sendVideoRTP:data length:len];
    }
    virtual bool SendRtcp(const uint8_t* data, size_t len) {
//        NSLog(@"send rtcp:%ld", len);
        return [e_ sendVideoRTCP:data length:len];
    }
    
    void OnLoadUpdate(Load load) {
        NSLog(@"cpu load:%d", load);
    }
    
private:
    __weak VOIPEngine *e_;
};



@implementation VOIPEngine
-(id)init {
    self = [super init];
    if (self) {
        engine_ = new AVEngine(self);
        self.packets = [NSMutableArray array];
        
        pthread_mutexattr_t attr;
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
        
        pthread_mutex_init(&mutex_, &attr);
        pthread_cond_init(&cond_, NULL);


    }
    return self;
}

-(void)dealloc {
    delete engine_;
    
    pthread_mutex_destroy(&mutex_);
    pthread_cond_destroy(&cond_);
}

-(void)listenVOIP {
    
    struct sockaddr_in addr;
    self.udpFD = socket(AF_INET,SOCK_DGRAM,0);
    bzero(&addr,sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr=htonl(INADDR_ANY);
    addr.sin_port=htons(self.voipPort);
    
    int one = 1;
    setsockopt(self.udpFD, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    
    int bufSize = 0;
    socklen_t size = sizeof(bufSize);
    getsockopt(self.udpFD, SOL_SOCKET, SO_RCVBUF, (void*)&bufSize, &size);
    NSLog(@"udp recv buf size:%d", bufSize);
    bufSize = 1024 * 1024;
    if (setsockopt(self.udpFD, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(int)) == -1) {
        NSLog(@"set sock recv buf size error");
    } else {
        NSLog(@"new udp recv buf size:%d", bufSize);
    }
    
    
    bind(self.udpFD, (struct sockaddr *)&addr,sizeof(addr));
    
    voip_sock_nonblock(self.udpFD, 1);
}

-(void)deliverLoop {

    while (self.running) {
        pthread_mutex_lock(&mutex_);
        
        while (self.packets.count == 0 && self.running) {
            struct timeval tv;
            struct timespec ts;
            gettimeofday(&tv, NULL);
            ts.tv_sec = tv.tv_sec;
            ts.tv_nsec = tv.tv_usec*1000 + 1000*1000*100;
            pthread_cond_timedwait(&cond_, &mutex_, &ts);
        }

        NSMutableArray *packets = self.packets;
        self.packets = [NSMutableArray array];
    
        pthread_mutex_unlock(&mutex_);
        
        for (VOIPData *data in packets) {
            [self onVOIPData:data];
        }
    }
}

-(void)recvLoop {
    struct sockaddr_in addr;
    self.udpFD = socket(AF_INET,SOCK_DGRAM,0);
    bzero(&addr,sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr=htonl(INADDR_ANY);
    addr.sin_port=htons(self.voipPort);
    
    int one = 1;
    setsockopt(self.udpFD, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(one));
    int bufSize = 0;
    socklen_t size = sizeof(bufSize);
    getsockopt(self.udpFD, SOL_SOCKET, SO_RCVBUF, (void*)&bufSize, &size);
    NSLog(@"udp recv buf size:%d", bufSize);
    bufSize = 1024 * 1024;
    if (setsockopt(self.udpFD, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(int)) == -1) {
        NSLog(@"set sock recv buf size error");
    } else {
        NSLog(@"new udp recv buf size:%d", bufSize);
    }
    
    bind(self.udpFD, (struct sockaddr *)&addr,sizeof(addr));
    
    voip_sock_nonblock(self.udpFD, 1);
    

    [self sendAuth];
    NSDate *lastAuthTS = [NSDate date];
    while (self.running) {
        fd_set rds;
        struct timeval timeout;
        timeout.tv_sec = 0;
        timeout.tv_usec = 1000*400;//400ms

        FD_ZERO(&rds);
        FD_SET(self.udpFD, &rds);
        int r = select(self.udpFD + 1, &rds, NULL, NULL, &timeout);
        if (r == -1) {
            NSLog(@"select error:%s", strerror(errno));
            break;
        } else if (r == 1) {
            [self handleRead];
        }
        
        NSDate *now = [NSDate date];
        NSTimeInterval interval = [now timeIntervalSinceDate:lastAuthTS];
        if (!self.isAuth && interval > 1) {
            [self sendAuth];
            lastAuthTS = now;
        } else if (self.isAuth && interval > 10) {
            [self sendAuth];
            lastAuthTS = now;
        }
    }

    close(self.udpFD);
}


-(void)handleVOIPData:(const char*)buf length:(size_t)len addr:(struct sockaddr_in*)addr {
    if (len <= 18) {
        NSLog(@"no audio data");
        return;
    }
    
    VOIPData *vdata = [[VOIPData alloc] init];
    const char *p = buf;
    
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
    
    vdata.content = [NSData dataWithBytes:p length:len-18];
    
    int ip = ntohl(addr->sin_addr.s_addr);
    int port = ntohs(addr->sin_port);
    
    if (!self.isPeerConnected && self.calleeIP == ip && self.calleePort == port) {
        self.isPeerConnected = YES;
        NSLog(@"peer connected");
    }
    
    pthread_mutex_lock(&mutex_);
    [self.packets addObject:vdata];
    pthread_cond_signal(&cond_);
    pthread_mutex_unlock(&mutex_);
}

-(void)handleAuthStatus:(const char*)buf length:(size_t)len {
    if (len == 0) {
        return;
    }
    int status = *buf;
    if (status == 0) {
        self.auth = YES;
    }
    NSLog(@"voip tunnel auth status:%d", status);
}

-(void)handleRead {
    char buf[64*1024] = {0};
    struct sockaddr_in addr;
    socklen_t len = sizeof(addr);
    size_t n = recvfrom(self.udpFD, buf, 64*1024, 0, (struct sockaddr*)&addr, &len);
    if (n <= 0) {
        NSLog(@"recv udp error:%d, %s", errno, strerror(errno));
        return;
    }

    int cmd = buf[0] & 0x0f;
    if (cmd == VOIP_AUTH_STATUS) {
        [self handleAuthStatus:buf+1 length:n-1];
    } else if (cmd == VOIP_DATA) {
        [self handleVOIPData:buf+1 length:n-1 addr:&addr];
    }
}

-(void)onVOIPData:(VOIPData*)data {
    if (data.sender != self.callee) {
        NSLog(@"skip data...");
        return;
    }
    
    const void *packet = [data.content bytes];
    NSInteger packet_length = [data.content length];
    
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    if (self.videoEnabled) {
        if (self.recvStream == nil) {
            NSLog(@"skip data...");
            return;
        }
        int channel = self.recvStream.voiceChannel;
        if (data.isRTP) {
            if (data.type == VOIP_AUDIO) {
                rtc.voe_network->ReceivedRTPPacket(channel, packet, packet_length);
            } else if (data.type == VOIP_VIDEO) {
                call_->Receiver()->DeliverPacket(webrtc::MediaType::VIDEO, (const uint8_t*)packet, packet_length);
            }
        } else {
            if (data.type == VOIP_AUDIO) {
                rtc.voe_network->ReceivedRTCPPacket(channel, packet, packet_length);
            } else if (data.type == VOIP_VIDEO) {
                call_->Receiver()->DeliverPacket(webrtc::MediaType::VIDEO, (const uint8_t*)packet, packet_length);
            }
        }
    } else {
        if (self.audioRecvStream == nil) {
            NSLog(@"skip data...");
            return;
        }
        int channel = self.audioRecvStream.voiceChannel;

        if (data.isRTP) {
            if (data.type == VOIP_AUDIO) {
                rtc.voe_network->ReceivedRTPPacket(channel, packet, packet_length);
            }
        } else {
            if (data.type == VOIP_AUDIO) {
                rtc.voe_network->ReceivedRTCPPacket(channel, packet, packet_length);
            }
        }
    }
}



-(void)startAVStream {
    NSLog(@"engine start stream");
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    int error;
    int audio_playback_device_index = 0;
    error = rtc.voe_hardware->SetPlayoutDevice(audio_playback_device_index);
    
    int audio_capture_device_index = 0;
    error = rtc.voe_hardware->SetRecordingDevice(audio_capture_device_index);
    
    error = rtc.voe_apm->SetNsStatus(true, webrtc::kNsHighSuppression);
    error = rtc.voe_apm->SetEcStatus(true);
    
    webrtc::Call::Config config(engine_);
    config.overuse_callback = engine_;
    config.voice_engine = rtc.voice_engine;
    
    config.bitrate_config.min_bitrate_bps = kMinBandwidthBps;
    config.bitrate_config.start_bitrate_bps = kStartBandwidthBps;
    config.bitrate_config.max_bitrate_bps = kMaxBandwidthBps;
    call_ = webrtc::Call::Create(config);
    
    
    if (!self.videoEnabled) {
        self.audioSendStream = [[AudioSendStream alloc] init];
        self.audioSendStream.voiceTransport = self;
        [self.audioSendStream start];
        
        self.audioRecvStream = [[AudioReceiveStream alloc] init];
        self.audioRecvStream.voiceTransport = self;
        [self.recvStream start];
        
    } else {
        self.sendStream = [[AVSendStream alloc] init];
        self.sendStream.voiceTransport = self;
        self.sendStream.render = self.localRender;
        self.sendStream.call = call_;
        
        //caller(1:3)
        //callee(2:4)
        if (self.isCaller) {
            self.sendStream.videoSSRC = 1;
            self.sendStream.voiceSSRC = 11;
            self.sendStream.rtxSSRC = 101;
        } else {
            self.sendStream.videoSSRC = 2;
            self.sendStream.voiceSSRC = 12;
            self.sendStream.rtxSSRC = 102;
        }
        
        [self.sendStream start];
        
        self.recvStream = [[AVReceiveStream alloc] init];
        self.recvStream.voiceTransport = self;
        self.recvStream.render = self.remoteRender;
        self.recvStream.call = call_;
        if (self.isCaller) {
            self.recvStream.localVideoSSRC = 3;
            self.recvStream.remoteVideoSSRC = 2;
            
            self.recvStream.localVoiceSSRC = 13;
            self.recvStream.remoteVoiceSSRC = 12;
            
            self.recvStream.rtxSSRC = 102;
        } else {
            self.recvStream.localVideoSSRC = 4;
            self.recvStream.remoteVideoSSRC = 1;
            
            self.recvStream.localVoiceSSRC = 14;
            self.recvStream.remoteVoiceSSRC = 11;
            
            self.recvStream.rtxSSRC = 101;
        }
        
        [self.recvStream start];
    }
}

-(void)startVoiceStream {
    NSLog(@"engine start stream");
    WebRTC *rtc = [WebRTC sharedWebRTC];
    
    int error;
    int audio_playback_device_index = 0;
    error = rtc.voe_hardware->SetPlayoutDevice(audio_playback_device_index);
    
    int audio_capture_device_index = 0;
    error = rtc.voe_hardware->SetRecordingDevice(audio_capture_device_index);
    
    error = rtc.voe_apm->SetNsStatus(true, webrtc::kNsHighSuppression);
    error = rtc.voe_apm->SetEcStatus(true);
    
    if (!self.videoEnabled) {
        self.audioSendStream = [[AudioSendStream alloc] init];
        self.audioSendStream.voiceTransport = self;
        [self.audioSendStream start];
        
        self.audioRecvStream = [[AudioReceiveStream alloc] init];
        self.audioRecvStream.voiceTransport = self;
        [self.audioRecvStream start];
    }
}

-(void)startStream {
    if (self.videoEnabled) {
        [self startAVStream];
    } else {
        [self startVoiceStream];
    }

    self.running = YES;
    pthread_create(&thread_, NULL, recv_thread, (__bridge void*)self);
    pthread_create(&deliverThread_, NULL, deliver_thread, (__bridge void*)self);
    
    self.beginDate = [NSDate date];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.sendStream sendKeyFrame];
    });
}

-(void)stopAVStream {
    [self.sendStream stop];
    [self.recvStream stop];
    self.sendStream = NULL;
    self.recvStream = NULL;
    
    delete call_;
    call_ = NULL;
}

-(void)stopVoiceStream {
    [self.audioSendStream stop];
    [self.audioRecvStream stop];
    self.audioSendStream = NULL;
    self.audioRecvStream = NULL;
}
-(void)stopStream {
    NSLog(@"engine stop stream");
    
    if (self.videoEnabled) {
        [self stopAVStream];
    } else {
        [self stopVoiceStream];
    }
    self.running = NO;
    pthread_join(thread_, NULL);
    pthread_join(deliverThread_, NULL);
    
    [self.packets removeAllObjects];
}

-(void)closeUDP {
    close(self.udpFD);
    self.udpFD = -1;
}

-(BOOL)isP2P {
    if (self.calleeIP != 0) {
        return YES;
    }
    
    return NO;
}

-(BOOL)sendVOIPData:(VOIPData*)data ip:(int)ip port:(short)port withHeader:(BOOL)withHeader {
    if (self.udpFD == -1) {
        return NO;
    }
    if (data.content.length > 60*1024) {
        return NO;
    }
    
    char buff[64*1024];
    char *p = buff;
    if (withHeader) {
        *p = (char)VOIP_DATA;
        p++;
    }
    
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
    
    NSInteger bufLen = 0;
    if (withHeader) {
        bufLen = len + 19;
    } else {
        bufLen = len + 18;
    }
    
    size_t r = sendto(self.udpFD, buff, bufLen, 0, (struct sockaddr*)&addr, sizeof(addr));
    if (r == -1) {
        NSLog(@"send voip data error:%s", strerror(errno));
    }
    
    return YES;
}

-(void)sendAuth {
    if (self.token.length == 0) {
        NSLog(@"token is empty");
        return;
    }
    char buff[64*1024] = {0};
    char *p = buff;
    *p = (char)VOIP_AUTH;
    p++;
    const char *t = [self.token UTF8String];
    size_t len = strlen(t);
    voip_writeInt16(len, p);
    p+=2;
    memcpy(p, t, len);
    p += len;
    

    int ip = inet_addr([self.relayIP UTF8String]);
    ip = ntohl(ip);
    short port = self.voipPort;
    
    struct sockaddr_in addr;
    bzero(&addr, sizeof(addr));
    
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr=htonl(ip);
    addr.sin_port=htons(port);
    
    size_t r = sendto(self.udpFD, buff, len + 3, 0, (struct sockaddr*)&addr, sizeof(addr));
    if (r == -1) {
        NSLog(@"send voip data error:%s", strerror(errno));
    }
}

-(BOOL)sendVOIPDataToServer:(VOIPData*)data {
    if (self.relayIP.length == 0) {
        return NO;
    }
    if (!self.isAuth) {
        [self sendAuth];
    }

    int ip = inet_addr([self.relayIP UTF8String]);
    ip = ntohl(ip);
    return [self sendVOIPData:data ip:ip port:self.voipPort withHeader:YES];
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
        r = [self sendVOIPData:vData ip:self.calleeIP port:self.calleePort withHeader:!self.isPeerNoHeader];
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


-(BOOL)sendVideoRTP:(const void*)data length:(size_t)len {
    if (len < 12) {
        return NO;
    }
    const char *p = (const char*)data;
    int32_t ssrc = voip_readInt32(p+8);
//    NSLog(@"rtp ssrc:%d", ssrc);
    
    VOIPData *vData = [[VOIPData alloc] init];
    
    vData.sender = self.caller;
    vData.receiver = self.callee;
    vData.type = VOIP_VIDEO;
    vData.rtp = YES;
    vData.content = [NSData dataWithBytes:data length:len];
    //NSLog(@"send rtp package:%d", length);
    
    [self sendVOIPData:vData];
    return YES;
}

-(BOOL)sendVideoRTCP:(const void*)data length:(size_t)len {
    VOIPData *vData = [[VOIPData alloc] init];
    
    vData.sender = self.caller;
    vData.receiver = self.callee;
    vData.rtp = NO;
    vData.type = VOIP_VIDEO;
    vData.content = [NSData dataWithBytes:data length:len];
    
    [self sendVOIPData:vData];
    
    return YES;
}

@end
