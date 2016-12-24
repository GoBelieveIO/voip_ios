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

enum SessionMode {
    SESSION_VOICE,
    SESSION_VIDEO,
};
@interface VOIPSession()

@property(nonatomic, assign) enum SessionMode mode;
@property(nonatomic, assign) time_t dialBeginTimestamp;
@property(nonatomic) NSTimer *dialTimer;

@property(nonatomic, assign) time_t acceptTimestamp;
@property(nonatomic) NSTimer *acceptTimer;

@property(nonatomic, assign) time_t lastPingTimestamp;
@property(nonatomic) NSTimer *pingTimer;

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

- (void)close {
    if (self.dialTimer && self.dialTimer.isValid) {
        [self.dialTimer invalidate];
        self.dialTimer = nil;
    }
    if (self.acceptTimer && self.acceptTimer.isValid) {
        [self.acceptTimer invalidate];
        self.acceptTimer = nil;
    }
    
    if (self.pingTimer && self.pingTimer.isValid) {
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
}

- (void)sendDial {
    NSLog(@"dial...");
    if (self.mode == SESSION_VOICE) {
        [self sendControlCommand:VOIP_COMMAND_DIAL];
    } else if (self.mode == SESSION_VIDEO) {
        [self sendControlCommand:VOIP_COMMAND_DIAL_VIDEO];
    } else {
        NSAssert(NO, @"invalid session mode");
    }
    
    time_t now = time(NULL);
    if (now - self.dialBeginTimestamp >= 60) {
        NSLog(@"dial timeout");
        
        //ondialtimeout
        [self.delegate onDialTimeout];
    }
}

-(void)sendCommand:(VOIPCommand*)command {
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;
    
    NSDictionary *dict = @{@"voip":command.jsonDictionary};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    rt.content = s;
    
    [[VOIPService instance] sendRTMessage:rt];
}

-(void)sendControlCommand:(enum EVOIPCommand)cmd {
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = cmd;
    command.channelID = self.channelID;
    [self sendCommand:command];
}

-(void)sendRefused {
    [self sendControlCommand:VOIP_COMMAND_REFUSED];
}

-(void)sendTalking:(int64_t)receiver {
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;

    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = VOIP_COMMAND_TALKING;
    command.channelID = self.channelID;
 
    NSDictionary *dict = @{@"voip":command.jsonDictionary};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    rt.content = s;
    [[VOIPService instance] sendRTMessage:rt];
}

-(void)sendReset {
    [self sendControlCommand:VOIP_COMMAND_RESET];
}

-(void)sendConnected {
    [self sendControlCommand:VOIP_COMMAND_CONNECTED];
}

-(void)sendDialAccept {
    [self sendControlCommand:VOIP_COMMAND_ACCEPT];
    
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
}

-(void)sendHangUp {
    NSLog(@"send hang up");
    [self sendControlCommand:VOIP_COMMAND_HANG_UP];
}

#pragma mark - RTMessageObserver
-(void)onRTMessage:(RTMessage*)rt {
    VOIPSession *voip = self;
    NSData *data = [rt.content dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    NSDictionary *obj = [dict objectForKey:@"voip"];
    if (!obj) {
        return;
    }
    
    
    if (rt.sender != self.peerUID) {
        [self sendTalking:rt.sender];
        return;
    }
    
    
    VOIPCommand *command = [[VOIPCommand alloc] initWithContent:obj];
    
    NSLog(@"voip state:%d command:%d", voip.state, command.cmd);
    

    if (voip.state == VOIP_DIALING) {
        if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
            voip.state = VOIP_CONNECTED;
            [self.dialTimer invalidate];
            self.dialTimer = nil;

            //onconnected
            [self.delegate onConnected];
            [self ping];
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
            [self ping];
        }
    } else if (voip.state == VOIP_CONNECTED) {
        if (command.cmd == VOIP_COMMAND_HANG_UP) {
            voip.state = VOIP_HANGED_UP;

            //onhangup
            [self.delegate onHangUp];
        } else if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
        } else if (command.cmd == VOIP_COMMAND_PING) {
            self.lastPingTimestamp = time(NULL);
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
    self.state = VOIP_REFUSED;
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

-(void)sendPing {
    [self sendControlCommand:VOIP_COMMAND_PING];
    
    time_t now = time(NULL);
    
    if (now - self.lastPingTimestamp > 10) {
        [self.delegate onDisconnect];
    }
}

-(void)ping {
    self.lastPingTimestamp = time(NULL);
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                        target:self
                                                      selector:@selector(sendPing)
                                                      userInfo:nil
                                                       repeats:YES];
    [self sendPing];
}

@end
