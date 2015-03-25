//
//  IM.h
//  im
//
//  Created by houxh on 14-6-21.
//  Copyright (c) 2014年 potato. All rights reserved.
//

#import <Foundation/Foundation.h>

#define MSG_HEARTBEAT 1
#define MSG_AUTH 2
#define MSG_AUTH_STATUS 3
#define MSG_IM 4
#define MSG_ACK 5
#define MSG_RST 6
#define MSG_GROUP_NOTIFICATION 7
#define MSG_GROUP_IM 8
#define MSG_PEER_ACK 9
#define MSG_INPUTING 10
#define MSG_SUBSCRIBE_ONLINE_STATE 11
#define MSG_ONLINE_STATE 12
#define MSG_PING 13
#define MSG_PONG 14
#define MSG_AUTH_TOKEN 15
#define MSG_LOGIN_POINT 16


#define MSG_VOIP_CONTROL 64
#define MSG_VOIP_DATA 65

#define PLATFORM_IOS 1

enum VOIPCommand {
    VOIP_COMMAND_DIAL = 1,
    VOIP_COMMAND_ACCEPT,
    VOIP_COMMAND_CONNECTED,
    VOIP_COMMAND_REFUSE,
    VOIP_COMMAND_REFUSED,
    VOIP_COMMAND_HANG_UP,
    VOIP_COMMAND_RESET,
    
    //通话中
    VOIP_COMMAND_TALKING,
    
};

#define VOIP_AUDIO 1
#define VOIP_VIDEO 2

#define VOIP_RTP 1
#define VOIP_RTCP 2

@interface NatPortMap : NSObject
@property(nonatomic) int32_t ip;
@property(nonatomic) int16_t port;
@end

@interface VOIPControl : NSObject
@property(nonatomic, assign)int64_t sender;
@property(nonatomic, assign)int64_t receiver;
@property(nonatomic, assign) int32_t cmd;
@property(nonatomic, assign) int32_t dialCount;//只对VOIP_COMMAND_DIAL有意义
@property(nonatomic) NatPortMap *natMap;//VOIP_COMMAND_ACCEPT，VOIP_COMMAND_CONNECTED
@property(nonatomic) int32_t relayIP;//VOIP_COMMAND_CONNECTED, 中转服务器ip地址
@end

@interface VOIPAuthenticationToken : NSObject
@property(nonatomic, copy) NSString *token;
@property(nonatomic, assign) int8_t platformID;
@property(nonatomic, copy) NSString *deviceID;
@end

@interface VOIPMessage : NSObject
@property(nonatomic, assign)int cmd;
@property(nonatomic, assign)int seq;
@property(nonatomic) NSObject *body;

-(NSData*)pack;

-(BOOL)unpack:(NSData*)data;
@end
