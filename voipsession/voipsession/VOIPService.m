//
//  IMService.m
//  im
//
//  Created by houxh on 14-6-26.
//  Copyright (c) 2014年 potato. All rights reserved.
//
#include <netdb.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#import "VOIPService.h"
#import "VOIPTCP.h"
#import "VOIPMessage.h"
#import "VOIPUtil.h"
#import "VOIPReachability.h"

#define HEARTBEAT (180ull*NSEC_PER_SEC)

#define HOST @"voipnode.gobelieve.io"
#define PORT 20000

@interface VOIPService()

@property(atomic, assign) time_t timestmap;


@property(nonatomic, assign)BOOL stopped;
@property(nonatomic, assign)BOOL suspended;
@property(nonatomic, assign)BOOL isBackground;

@property(nonatomic)VOIPTCP *tcp;
@property(nonatomic, strong)dispatch_source_t connectTimer;
@property(nonatomic, strong)dispatch_source_t heartbeatTimer;
@property(nonatomic)int connectFailCount;
@property(nonatomic)int seq;
@property(nonatomic)NSMutableArray *observers;
@property(nonatomic)NSMutableData *data;

@property(nonatomic)NSMutableArray *voipObservers;

@property(nonatomic)VOIPReachability *reach;
@property(nonatomic)BOOL reachable;

@end

@implementation VOIPService
+(VOIPService*)instance {
    static VOIPService *im;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!im) {
            im = [[VOIPService alloc] init];
        }
    });
    return im;
}

-(id)init {
    self = [super init];
    if (self) {
        dispatch_queue_t queue = dispatch_get_main_queue();
        self.connectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_event_handler(self.connectTimer, ^{
            [self connect];
        });

        self.heartbeatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,queue);
        dispatch_source_set_event_handler(self.heartbeatTimer, ^{
            [self sendHeartbeat];
        });
        self.voipObservers = [NSMutableArray array];
        self.observers = [NSMutableArray array];
        self.data = [NSMutableData data];
        self.connectState = STATE_UNCONNECTED;
        self.stopped = YES;
        self.suspended = YES;
        self.reachable = YES;
        self.isBackground = NO;
        
        self.host = HOST;
        self.port = PORT;
    }
    return self;
}


-(void)startRechabilityNotifier {
    VOIPService *wself = self;
    self.reach = [VOIPReachability reachabilityForInternetConnection];
    
    self.reach.reachableBlock = ^(VOIPReachability*reach) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"internet reachable");
            wself.reachable = YES;
            if (wself != nil && !wself.stopped && !wself.isBackground) {
                [wself resume];
            }
        });
    };
    
    self.reach.unreachableBlock = ^(VOIPReachability*reach) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"internet unreachable");
            wself.reachable = NO;
            if (wself != nil && !wself.stopped) {
                [wself suspend];
            }
        });
    };
    
    [self.reach startNotifier];
}

-(void)enterForeground {
    NSLog(@"im service enter foreground");
    self.isBackground = NO;
    if (!self.stopped && self.reachable) {
        [self resume];
    }
}

-(void)enterBackground {
    NSLog(@"im service enter background");
    self.isBackground = YES;
    if (!self.stopped) {
        [self suspend];
    }
}


-(void)start {
    if (!self.host || !self.port) {
        NSLog(@"should init im server host and port");
        exit(1);
    }
    if (!self.stopped) {
        return;
    }
    NSLog(@"start im service");
    self.stopped = NO;
    if (self.reachable) {
        [self resume];
    }
}

-(void)stop {
    if (self.stopped) {
        return;
    }
    NSLog(@"stop im service");
    self.stopped = YES;
    
    [self suspend];
}



-(void)suspend {
    if (self.suspended) {
        return;
    }
    
    NSLog(@"suspend im service");
    self.suspended = YES;
    
    dispatch_suspend(self.connectTimer);
    dispatch_suspend(self.heartbeatTimer);
    
    self.connectState = STATE_UNCONNECTED;
    [self publishConnectState:STATE_UNCONNECTED];
    [self close];
}

-(void)resume {
    if (!self.suspended) {
        return;
    }
    NSLog(@"resume im service");
    self.suspended = NO;
    
    dispatch_time_t w = dispatch_walltime(NULL, 0);
    dispatch_source_set_timer(self.connectTimer, w, DISPATCH_TIME_FOREVER, 0);
    dispatch_resume(self.connectTimer);
    
    w = dispatch_walltime(NULL, HEARTBEAT);
    dispatch_source_set_timer(self.heartbeatTimer, w, HEARTBEAT, HEARTBEAT/2);
    dispatch_resume(self.heartbeatTimer);
    
    [self refreshHostIP];
}


-(void)close {
    if (self.tcp) {
        [self.tcp close];
        self.tcp = nil;
    }
}

-(void)startConnectTimer {
    //重连
    int64_t t = 0;
    if (self.connectFailCount > 60) {
        t = 60ull*NSEC_PER_SEC;
    } else {
        t = self.connectFailCount*NSEC_PER_SEC;
    }
    
    dispatch_time_t w = dispatch_walltime(NULL, t);
    dispatch_source_set_timer(self.connectTimer, w, DISPATCH_TIME_FOREVER, 0);
    
    NSLog(@"start connect timer:%lld", t/NSEC_PER_SEC);
}

-(void)handleClose {
    self.connectState = STATE_UNCONNECTED;
    [self publishConnectState:STATE_UNCONNECTED];
    
    [self close];
    [self startConnectTimer];
}


-(void)handleAuthStatus:(VOIPMessage*)msg {
    int status = [(NSNumber*)msg.body intValue];
    NSLog(@"auth status:%d", status);
    if (status != 0) {
        //失效的accesstoken,2s后重新连接
        self.connectFailCount = 2;
        [self close];
        [self startConnectTimer];
        self.connectState = STATE_UNCONNECTED;
        [self publishConnectState:STATE_UNCONNECTED];
    }
}

-(void)handleVOIPControl:(VOIPMessage*)msg {
    VOIPControl *ctl = (VOIPControl*)msg.body;
    id<VOIPObserver> ob = [self.voipObservers lastObject];
    if (ob) {
        [ob onVOIPControl:ctl];
    }
}


-(void)publishConnectState:(int)state {
    for (id<VOIPConnectObserver> ob in self.observers) {
        [ob onConnectState:state];
    }
}

-(void)handleMessage:(VOIPMessage*)msg {
    if (msg.cmd == MSG_AUTH_STATUS) {
        [self handleAuthStatus:msg];
    } else if (msg.cmd == MSG_VOIP_CONTROL) {
        [self handleVOIPControl:msg];
    }
}

-(BOOL)handleData:(NSData*)data {
    [self.data appendData:data];
    int pos = 0;
    const uint8_t *p = [self.data bytes];
    while (YES) {
        if (self.data.length < pos + 4) {
            break;
        }
        int len = voip_readInt32(p+pos);
        if (self.data.length < 4 + 8 + pos + len) {
            break;
        }
        NSData *tmp = [NSData dataWithBytes:p+4+pos length:len + 8];
        VOIPMessage *msg = [[VOIPMessage alloc] init];
        if (![msg unpack:tmp]) {
            NSLog(@"unpack message fail");
            return NO;
        }
        [self handleMessage:msg];
        pos += 4+8+len;
    }
    self.data = [NSMutableData dataWithBytes:p+pos length:self.data.length - pos];
    return YES;
}

-(void)onRead:(NSData*)data error:(int)err {
    if (err) {
        NSLog(@"tcp read err");
        [self handleClose];
        return;
    } else if (!data) {
        NSLog(@"tcp closed");
        [self handleClose];
        return;
    } else {
        BOOL r = [self handleData:data];
        if (!r) {
            [self handleClose];
        }
    }
}

-(NSString*)resolveIP:(NSString*)host {
    struct addrinfo hints;
    struct addrinfo *result, *rp;
    int s;
    
    char buf[32];
    snprintf(buf, 32, "%d", 0);
    
    memset(&hints, 0, sizeof(struct addrinfo));
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_protocol = IPPROTO_TCP;
    hints.ai_flags = 0;
    
    s = getaddrinfo([host UTF8String], buf, &hints, &result);
    if (s != 0) {
        return nil;
    }
    NSString *ip = nil;
    for (rp = result; rp != NULL; rp = rp->ai_next) {
        struct sockaddr_in *addr = (struct sockaddr_in*)rp->ai_addr;
        const char *str = inet_ntoa(addr->sin_addr);
        ip = [NSString stringWithUTF8String:str];
        break;
    }
    
    freeaddrinfo(result);
    return ip;
}

-(void)refreshHostIP {
    NSLog(@"refresh host ip...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *ip = [self resolveIP:self.host];
        if ([ip length] > 0) {
            self.hostIP = ip;
            self.timestmap = time(NULL);
        }
    });
}

-(void)connect {
    if (self.tcp) {
        NSLog(@"tcp already connected");
        return;
    }
    if (self.stopped) {
        NSLog(@"im service already stopped");
        return;
    }
    
    NSString *host = self.hostIP;
    if (host.length == 0) {
        [self refreshHostIP];
        self.connectFailCount = self.connectFailCount + 1;
        [self startConnectTimer];
        return;
    }
    time_t now = time(NULL);
    if (now - self.timestmap > 5*60) {
        [self refreshHostIP];
    }
    
    self.connectState = STATE_CONNECTING;
    [self publishConnectState:STATE_CONNECTING];
    self.tcp = [[VOIPTCP alloc] init];
    BOOL r = [self.tcp connect:self.host port:self.port cb:^(VOIPTCP *tcp, int err) {
        if (err) {
            NSLog(@"tcp connect err");
            [self close];
            self.connectFailCount = self.connectFailCount + 1;
            self.connectState = STATE_CONNECTFAIL;
            [self publishConnectState:STATE_CONNECTFAIL];
            
            [self startConnectTimer];
            return;
        } else {
            NSLog(@"tcp connected");
            self.connectFailCount = 0;
            self.connectState = STATE_CONNECTED;
            [self publishConnectState:STATE_CONNECTED];
            [self sendAuth];
            [self.tcp startRead:^(VOIPTCP *tcp, NSData *data, int err) {
                [self onRead:data error:err];
            }];
        }
    }];
    if (!r) {
        NSLog(@"tcp connect err");
        self.tcp = nil;
        self.connectFailCount = self.connectFailCount + 1;
        self.connectState = STATE_CONNECTFAIL;
        [self publishConnectState:STATE_CONNECTFAIL];
        
        [self startConnectTimer];
    }
}

-(BOOL)sendMessage:(VOIPMessage *)msg {
    if (!self.tcp || self.connectState != STATE_CONNECTED) return NO;
    self.seq = self.seq + 1;
    msg.seq = self.seq;

    NSMutableData *data = [NSMutableData data];
    NSData *p = [msg pack];
    if (!p) {
        NSLog(@"message pack error");
        return NO;
    }
    char b[4];
    voip_writeInt32(p.length-8, b);
    [data appendBytes:(void*)b length:4];
    [data appendData:p];
    [self.tcp write:data];
    return YES;
}

-(void)sendHeartbeat {
    NSLog(@"send heartbeat");
    VOIPMessage *msg = [[VOIPMessage alloc] init];
    msg.cmd = MSG_HEARTBEAT;
    [self sendMessage:msg];
}


-(void)sendAuth {
    NSLog(@"send auth");
    VOIPMessage *msg = [[VOIPMessage alloc] init];
    msg.cmd = MSG_AUTH_TOKEN;
    VOIPAuthenticationToken *auth = [[VOIPAuthenticationToken alloc] init];
    auth.token = self.token;
    auth.platformID = PLATFORM_IOS;
    auth.deviceID = self.deviceID;
    msg.body = auth;
    [self sendMessage:msg];
}

-(void)addMessageObserver:(id<VOIPObserver>)ob {
    [self.observers addObject:ob];
}

-(void)removeMessageObserver:(id<VOIPObserver>)ob {
    [self.observers removeObject:ob];
}

-(void)pushVOIPObserver:(id<VOIPObserver>)ob {
    [self.voipObservers addObject:ob];
}

-(void)popVOIPObserver:(id<VOIPObserver>)ob {
    int count = [self.voipObservers count];
    if (count == 0) {
        return;
    }
    id<VOIPObserver> top = [self.voipObservers objectAtIndex:count-1];
    if (top == ob) {
        [self.voipObservers removeObject:top];
    }
}

-(BOOL)sendVOIPControl:(VOIPControl*)ctl {
    VOIPMessage *m = [[VOIPMessage alloc] init];
    m.cmd = MSG_VOIP_CONTROL;
    m.body = ctl;
    return [self sendMessage:m];
}

@end
