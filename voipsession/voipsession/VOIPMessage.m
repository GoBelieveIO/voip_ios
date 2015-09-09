/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import "VOIPMessage.h"
#import "VOIPUtil.h"

#define HEAD_SIZE 8

@implementation NatPortMap

@end

@implementation VOIPControl

@end

@implementation VOIPAuthenticationToken

@end

@implementation VOIPAuthenticationStatus

@end

@implementation VOIPMessage
-(NSData*)pack {
    char buf[64*1024] = {0};
    char *p = buf;

    voip_writeInt32(self.seq, p);
    p += 4;
    *p = (uint8_t)self.cmd;
    p += 4;
    
    if (self.cmd == MSG_HEARTBEAT) {
        return [NSData dataWithBytes:buf length:HEAD_SIZE];
    } else if (self.cmd == MSG_AUTH) {
        int64_t uid = [(NSNumber*)self.body longLongValue];
        voip_writeInt64(uid, p);
        return [NSData dataWithBytes:buf length:HEAD_SIZE+8];
    } else if (self.cmd == MSG_AUTH_TOKEN) {
        VOIPAuthenticationToken *auth = (VOIPAuthenticationToken*)self.body;
        *p++ = auth.platformID;
        const char *t;
        t = [auth.token UTF8String];
        *p++ = strlen(t);
        memcpy(p, t, strlen(t));
        p += strlen(t);
        t = [auth.deviceID UTF8String];
        *p++ = strlen(t);
        memcpy(p, t, strlen(t));
        p += strlen(t);
        return [NSData dataWithBytes:buf length:(p-buf)];
    } else if (self.cmd == MSG_VOIP_CONTROL) {
        VOIPControl *ctl = (VOIPControl*)self.body;
        voip_writeInt64(ctl.sender, p);
        p += 8;
        voip_writeInt64(ctl.receiver, p);
        p += 8;

        voip_writeInt32(ctl.cmd, p);
        p += 4;
        if (ctl.cmd == VOIP_COMMAND_DIAL || ctl.cmd == VOIP_COMMAND_DIAL_VIDEO) {
            voip_writeInt32(ctl.dialCount, p);
            p += 4;
            return [NSData dataWithBytes:buf length:HEAD_SIZE+24];
        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT) {
            NSLog(@"nat map ip:%x", ctl.natMap.ip);
            voip_writeInt32(ctl.natMap.ip, p);
            p += 4;
            voip_writeInt16(ctl.natMap.port, p);
            p += 2;
            return [NSData dataWithBytes:buf length:HEAD_SIZE+26];
        } else if (ctl.cmd == VOIP_COMMAND_CONNECTED) {
            NSLog(@"nat map ip:%x", ctl.natMap.ip);
            voip_writeInt32(ctl.natMap.ip, p);
            p += 4;
            voip_writeInt16(ctl.natMap.port, p);
            p += 2;
            voip_writeInt32(ctl.relayIP, p);
            p += 4;
            return [NSData dataWithBytes:buf length:HEAD_SIZE+30];
        } else {
            return [NSData dataWithBytes:buf length:HEAD_SIZE+20];
        }
    } 
    return nil;
}

-(BOOL)unpack:(NSData*)data {
    const char *p = [data bytes];
    self.seq = voip_readInt32(p);
    p += 4;
    self.cmd = *p;
    p += 4;
    NSLog(@"seq:%d cmd:%d", self.seq, self.cmd);
    if (self.cmd == MSG_RST) {
        return YES;
    } else if (self.cmd == MSG_AUTH_STATUS) {
        VOIPAuthenticationStatus *status = [[VOIPAuthenticationStatus alloc] init];
        status.status = voip_readInt32(p);
        p += 4;
        status.ip = voip_readInt32(p);
        self.body = status;
        return YES;
    } else if (self.cmd == MSG_VOIP_CONTROL) {
        VOIPControl *ctl = [[VOIPControl alloc] init];
        ctl.sender = voip_readInt64(p);
        p += 8;
        ctl.receiver = voip_readInt64(p);
        p += 8;
        ctl.cmd = voip_readInt32(p);
        p += 4;
        if (ctl.cmd == VOIP_COMMAND_DIAL || ctl.cmd == VOIP_COMMAND_DIAL_VIDEO) {
            ctl.dialCount = voip_readInt32(p);
        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT) {
            if (data.length >= HEAD_SIZE + 26) {
                ctl.natMap = [[NatPortMap alloc] init];
                ctl.natMap.ip = voip_readInt32(p);
                p += 4;
                ctl.natMap.port = voip_readInt16(p);
                p += 2;
            }
        } else if (ctl.cmd == VOIP_COMMAND_CONNECTED) {
            if (data.length >= HEAD_SIZE + 26) {
                ctl.natMap = [[NatPortMap alloc] init];
                ctl.natMap.ip = voip_readInt32(p);
                p += 4;
                ctl.natMap.port = voip_readInt16(p);
                p += 2;
            }
            if (data.length >= HEAD_SIZE + 30) {
                ctl.relayIP = voip_readInt32(p);
                p += 4;
            }
        }
        self.body = ctl;
        return YES;
    }
    return NO;
}

@end
