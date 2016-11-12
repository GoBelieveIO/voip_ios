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
#import "VOIPSession.h"
#import "VOIPService.h"

//#define VOIP_HOST @"voipnode.gobelieve.io"
//#define VOIP_PORT 20002
//#define STUN_SERVER  @"stun.counterpath.net"

//static NSString *g_voipHost = VOIP_HOST;

enum SessionMode {
    SESSION_VOICE,
    SESSION_VIDEO,
};
@interface VOIPSession()

@property(nonatomic, assign) SessionMode mode;
@property(nonatomic, assign) int dialCount;
@property(nonatomic, assign) time_t dialBeginTimestamp;
@property(nonatomic) NSTimer *dialTimer;

@property(nonatomic, assign) time_t acceptTimestamp;
@property(nonatomic) NSTimer *acceptTimer;

@property(nonatomic, assign) time_t refuseTimestamp;
@property(nonatomic) NSTimer *refuseTimer;

@property(atomic, copy) NSString *voipHostIP;
@property(atomic) BOOL refreshing;

@end

@implementation VOIPSession


-(id)init {
    self = [super init];
    if (self) {
        self.state = VOIP_ACCEPTING;
        self.refreshing = NO;
    }
    return self;
}

-(NSString*)IP2String:(struct in_addr)addr {
    char buf[64] = {0};
    const char *p = inet_ntop(AF_INET, &addr, buf, 64);
    if (p) {
        return [NSString stringWithUTF8String:p];
    }
    return nil;
    
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
        NSLog(@"get addr info error:%s", gai_strerror(s));
        return nil;
    }
    NSString *ip = nil;
    rp = result;
    if (rp != NULL) {
        struct sockaddr_in *addr = (struct sockaddr_in*)rp->ai_addr;
        ip = [self IP2String:addr->sin_addr];
    }
    freeaddrinfo(result);
    return ip;
}





- (void)sendDial {
    NSLog(@"dial...");
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    
    VOIPCommand *command = [[VOIPCommand alloc] init];

    if (self.mode == SESSION_VOICE) {
        command.cmd = VOIP_COMMAND_DIAL;
    } else if (self.mode == SESSION_VIDEO) {
        command.cmd = VOIP_COMMAND_DIAL_VIDEO;
    } else {
        NSAssert(NO, @"invalid session mode");
    }
    
    command.dialCount = self.dialCount + 1;
    
    ctl.content = command.content;
    
    
    BOOL r = [[VOIPService instance] sendVOIPControl:ctl];
    if (r) {
        self.dialCount = self.dialCount + 1;
    } else {
        NSLog(@"dial fail");
    }
    
    
    time_t now = time(NULL);
    if (now - self.dialBeginTimestamp >= 60) {
        NSLog(@"dial timeout");
        
        //ondialtimeout
        [self.delegate onDialTimeout];
    }
}

-(void)sendCommand:(VOIPCommand*)command {
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    ctl.content = command.content;
    [[VOIPService instance] sendVOIPControl:ctl];
}

-(void)sendControlCommand:(enum EVOIPCommand)cmd {
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = cmd;
    [self sendCommand:command];
}

-(void)sendRefused {
    [self sendControlCommand:VOIP_COMMAND_REFUSED];
}

-(void)sendTalking:(int64_t)receiver {
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = receiver;
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = VOIP_COMMAND_TALKING;
    ctl.content = command.content;
    [[VOIPService instance] sendVOIPControl:ctl];
}

-(void)sendReset {
    [self sendControlCommand:VOIP_COMMAND_RESET];
}

-(void)sendConnected {
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = VOIP_COMMAND_CONNECTED;


    
    [self sendCommand:command];
}

-(void)sendDialAccept {
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = VOIP_COMMAND_ACCEPT;
    [self sendCommand:command];
    
    time_t now = time(NULL);
    if (now - self.acceptTimestamp >= 10) {
        NSLog(@"accept timeout");
        [self.acceptTimer invalidate];

        //onaccepttimeout
        [self.delegate onAcceptTimeout];
    }
}

-(void)sendDialRefuse {
    [self sendControlCommand:VOIP_COMMAND_REFUSE];
    
    time_t now = time(NULL);
    if (now - self.refuseTimestamp > 10) {
        NSLog(@"refuse timeout");
        [self.refuseTimer invalidate];
        
        VOIPSession *voip = self;
        voip.state = VOIP_REFUSED;

        [self.delegate onRefuseFinished];
    }
}

-(void)sendHangUp {
    NSLog(@"send hang up");
    [self sendControlCommand:VOIP_COMMAND_HANG_UP];
}

#pragma mark - VOIPObserver
-(void)onVOIPControl:(VOIPControl*)ctl {
    VOIPSession *voip = self;
    
    if (ctl.sender != self.peerUID) {
        [self sendTalking:ctl.sender];
        return;
    }
    
    VOIPCommand *command = [[VOIPCommand alloc] initWithContent:ctl.content];
    
    NSLog(@"voip state:%d command:%d", voip.state, command.cmd);
    

    if (voip.state == VOIP_DIALING) {
        if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
            voip.state = VOIP_CONNECTED;
            [self.dialTimer invalidate];
            self.dialTimer = nil;

            //onconnected
            [self.delegate onConnected];
        } else if (command.cmd == VOIP_COMMAND_REFUSE) {
            voip.state = VOIP_REFUSED;
            
            [self sendRefused];
            
            [self.dialTimer invalidate];
            self.dialTimer = nil;

            //onrefuse
            [self.delegate onRefuse];
            
        } else if (command.cmd == VOIP_COMMAND_TALKING) {
            voip.state = VOIP_SHUTDOWN;
            
            [self.dialTimer invalidate];
            self.dialTimer = nil;
            
            [self.delegate onTalking];
        }
    } else if (voip.state == VOIP_ACCEPTING) {
        if (command.cmd == VOIP_COMMAND_HANG_UP) {
            voip.state = VOIP_HANGED_UP;
            //onhangup
            [self.delegate onHangUp];
        }
    } else if (voip.state == VOIP_ACCEPTED) {
        if (command.cmd == VOIP_COMMAND_CONNECTED) {
            NSLog(@"called voip connected");
            [self.acceptTimer invalidate];
            voip.state = VOIP_CONNECTED;
            
            //onconnected
            [self.delegate onConnected];

        }
    } else if (voip.state == VOIP_CONNECTED) {
        if (command.cmd == VOIP_COMMAND_HANG_UP) {
            voip.state = VOIP_HANGED_UP;

            //onhangup
            [self.delegate onHangUp];
        } else if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
        }
    } else if (voip.state == VOIP_REFUSING) {
        if (command.cmd == VOIP_COMMAND_REFUSED) {
            NSLog(@"refuse finished");
            voip.state = VOIP_REFUSED;
            //onRefuseFinished
            [self.delegate onRefuseFinished];
        }
    }
}


-(void)dial {
    self.state = VOIP_DIALING;
    self.mode = SESSION_VOICE;
    
    self.dialBeginTimestamp = time(NULL);
    [self sendDial];
    self.dialTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                      target:self
                                                    selector:@selector(sendDial)
                                                    userInfo:nil
                                                     repeats:YES];
}

-(void)dialVideo {
    self.state = VOIP_DIALING;
    self.mode = SESSION_VIDEO;
    
    self.dialBeginTimestamp = time(NULL);
    [self sendDial];
    self.dialTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                      target:self
                                                    selector:@selector(sendDial)
                                                    userInfo:nil
                                                     repeats:YES];
}

-(void)accept {
    VOIPSession *voip = self;
    voip.state = VOIP_ACCEPTED;
    
    self.acceptTimestamp = time(NULL);
    self.acceptTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                        target:self
                                                      selector:@selector(sendDialAccept)
                                                      userInfo:nil
                                                       repeats:YES];
    [self sendDialAccept];
    


}
-(void)refuse {
    self.state = VOIP_REFUSING;
    
    self.refuseTimestamp = time(NULL);
    self.refuseTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                        target:self
                                                      selector:@selector(sendDialRefuse)
                                                      userInfo:nil
                                                       repeats:YES];
    
    [self sendDialRefuse];

}

-(void)hangUp {
    VOIPSession *voip = self;
    if (voip.state == VOIP_DIALING ) {
        [self.dialTimer invalidate];
        self.dialTimer = nil;

        [self sendHangUp];
        voip.state = VOIP_HANGED_UP;
    } else if (voip.state == VOIP_CONNECTED) {
        [self sendHangUp];
        voip.state = VOIP_HANGED_UP;
    }else {
        NSLog(@"invalid voip state:%d", voip.state);
    }
}


@end
