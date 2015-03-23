//
//  VOIP.m
//  Face
//
//  Created by houxh on 14-10-13.
//  Copyright (c) 2014年 beetle. All rights reserved.
//
#include <arpa/inet.h>
#import "VOIPSession.h"
#import "VOIPService.h"
#import "stun.h"

@interface VOIPSession()

@property(nonatomic, assign) int dialCount;
@property(nonatomic, assign) time_t dialBeginTimestamp;
@property(nonatomic) NSTimer *dialTimer;

@property(nonatomic, assign) time_t acceptTimestamp;
@property(nonatomic) NSTimer *acceptTimer;

@property(nonatomic, assign) time_t refuseTimestamp;
@property(nonatomic) NSTimer *refuseTimer;


@property(atomic, assign) StunAddress4 mappedAddr;
@property(atomic, assign) NatType natType;
@property(nonatomic) BOOL hairpin;

@end

@implementation VOIPSession

-(id)init {
    self = [super init];
    if (self) {
        self.state = VOIP_ACCEPTING;
    }
    return self;
}

-(void)holePunch {
    self.natType = StunTypeUnknown;
    self.hairpin = NO;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        StunAddress4 addr;
        BOOL hairpin = NO;
        NatType stype = [self mapNatAddress:&addr hairpin:&hairpin];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.natType = stype;
            self.mappedAddr = addr;
            
            
            if (self.localNatMap == nil) {
                self.localNatMap = [[NatPortMap alloc] init];
                self.localNatMap.ip = self.mappedAddr.addr;
                self.localNatMap.port = self.mappedAddr.port;
                
                //self.localNatMap.localIP = [self getPrimaryIP];
                //self.localNatMap.localPort = [Config instance].voipPort;
            }
            
        });
    });
}



#define VERBOSE false
-(NatType)mapNatAddress:(StunAddress4*)eaddr hairpin:(BOOL*)ph{
    int fd = -1;
    StunAddress4 mappedAddr;
    StunAddress4 stunServerAddr;
    NSString *stunServer = self.stunServer;
    stunParseServerName( (char*)[stunServer UTF8String], stunServerAddr);
    
    NSLog(@"nat mapping...");
    bool presPort = false, hairpin = false;
    NatType stype = stunNatType( stunServerAddr, VERBOSE, &presPort, &hairpin,
                                0, NULL);
    
    NSLog(@"nat type:%d", stype);
    *ph = hairpin;
    
    BOOL isOpen = NO;
    switch (stype)
    {
        case StunTypeFailure:
            break;
        case StunTypeUnknown:
            break;
        case StunTypeBlocked:
            break;
            
        case StunTypeOpen:
        case StunTypeFirewall:
            //todo get local address
        case StunTypeIndependentFilter:
        case StunTypeDependentFilter:
        case StunTypePortDependedFilter:
            isOpen = YES;
            break;
        case StunTypeDependentMapping:
            break;
        default:
            break;
    }
    
    
    if (!isOpen) {
        return stype;
    }
    for (int i = 0; i < 8; i++) {
        fd = stunOpenSocket(stunServerAddr, &mappedAddr, self.voipPort, NULL, VERBOSE);
        if (fd == -1) {
            continue;
        }
        break;
    }
    if (fd != -1) {
        close(fd);
        struct in_addr addr;
        addr.s_addr = htonl(mappedAddr.addr);
        NSLog(@"mapped address:%s:%d", inet_ntoa(addr), mappedAddr.port);
        *eaddr = mappedAddr;
    } else {
        NSLog(@"map nat address fail");
    }
    return stype;
}


- (void)sendDial {
    NSLog(@"dial...");
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    ctl.cmd = VOIP_COMMAND_DIAL;
    ctl.dialCount = self.dialCount + 1;
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

-(void)sendControlCommand:(enum VOIPCommand)cmd {
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    ctl.cmd = cmd;
    [[VOIPService instance] sendVOIPControl:ctl];
}

-(void)sendRefused {
    [self sendControlCommand:VOIP_COMMAND_REFUSED];
}

-(void)sendTalking {
    [self sendControlCommand:VOIP_COMMAND_TALKING];
}

-(void)sendReset {
    [self sendControlCommand:VOIP_COMMAND_RESET];
}

-(void)sendConnected {
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    ctl.cmd = VOIP_COMMAND_CONNECTED;
    ctl.natMap = self.localNatMap;
    
    [[VOIPService instance] sendVOIPControl:ctl];
}

-(void)sendDialAccept {
    VOIPControl *ctl = [[VOIPControl alloc] init];
    ctl.sender = self.currentUID;
    ctl.receiver = self.peerUID;
    ctl.cmd = VOIP_COMMAND_ACCEPT;
    ctl.natMap = self.localNatMap;
    
    [[VOIPService instance] sendVOIPControl:ctl];
    
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
        [self sendTalking];
        return;
    }
    NSLog(@"voip state:%d command:%d", voip.state, ctl.cmd);
    
    if (voip.state == VOIP_DIALING) {
        if (ctl.cmd == VOIP_COMMAND_ACCEPT) {
            self.peerNatMap = ctl.natMap;
            
            if (self.localNatMap == nil) {
                self.localNatMap = [[NatPortMap alloc] init];
            }
            
            [self sendConnected];
            voip.state = VOIP_CONNECTED;
            [self.dialTimer invalidate];
            self.dialTimer = nil;
            
            //onconnected
            [self.delegate onConnected];
        } else if (ctl.cmd == VOIP_COMMAND_REFUSE) {
            voip.state = VOIP_REFUSED;
            
            [self sendRefused];
            
            [self.dialTimer invalidate];
            self.dialTimer = nil;

            //onrefuse
            [self.delegate onRefuse];
            
        } else if (ctl.cmd == VOIP_COMMAND_DIAL) {
            //simultaneous open
            [self.dialTimer invalidate];
            self.dialTimer = nil;

            
            voip.state = VOIP_ACCEPTED;
            
            if (self.localNatMap == nil) {
                self.localNatMap = [[NatPortMap alloc] init];
            }
            
            self.acceptTimestamp = time(NULL);
            self.acceptTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                                target:self
                                                              selector:@selector(sendDialAccept)
                                                              userInfo:nil
                                                               repeats:YES];
            [self sendDialAccept];
        }
    } else if (voip.state == VOIP_ACCEPTING) {
        if (ctl.cmd == VOIP_COMMAND_HANG_UP) {
            voip.state = VOIP_HANGED_UP;
            //onhangup
            [self.delegate onHangUp];
        }
    } else if (voip.state == VOIP_ACCEPTED) {
        if (ctl.cmd == VOIP_COMMAND_CONNECTED) {
            NSLog(@"called voip connected");

            self.peerNatMap = ctl.natMap;
            
            [self.acceptTimer invalidate];
            voip.state = VOIP_CONNECTED;
            
            //onconnected
            [self.delegate onConnected];

        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT) {
            //simultaneous open
            NSLog(@"simultaneous voip connected");
            self.peerNatMap = ctl.natMap;
            
            [self.acceptTimer invalidate];
            voip.state = VOIP_CONNECTED;
            //onconnected
            [self.delegate onConnected];
       
        }
    } else if (voip.state == VOIP_CONNECTED) {
        if (ctl.cmd == VOIP_COMMAND_HANG_UP) {
            voip.state = VOIP_HANGED_UP;

            //onhangup
            [self.delegate onHangUp];
        } else if (ctl.cmd == VOIP_COMMAND_RESET) {
            voip.state = VOIP_RESETED;
            //onreset
            [self.delegate onReset];
        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
        }
    } else if (voip.state == VOIP_REFUSING) {
        if (ctl.cmd == VOIP_COMMAND_REFUSED) {
            NSLog(@"refuse finished");
            voip.state = VOIP_REFUSED;
            //onRefuseFinished
            [self.delegate onRefuseFinished];
        }
    }
}


-(void)dial {
    self.state = VOIP_DIALING;
    
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
    
    if (self.localNatMap == nil) {
        self.localNatMap = [[NatPortMap alloc] init];
    }
    
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
