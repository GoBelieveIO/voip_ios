//
//  IM.m
//  im
//
//  Created by houxh on 14-6-21.
//  Copyright (c) 2014年 potato. All rights reserved.
//

#import "Message.h"
#import "util.h"

#define HEAD_SIZE 8

@implementation NatPortMap

@end

@implementation VOIPControl

@end



@implementation Message
-(NSData*)pack {
    char buf[64*1024] = {0};
    char *p = buf;

    writeInt32(self.seq, p);
    p += 4;
    *p = (uint8_t)self.cmd;
    p += 4;
    
    if (self.cmd == MSG_HEARTBEAT) {
        return [NSData dataWithBytes:buf length:HEAD_SIZE];
    } else if (self.cmd == MSG_AUTH) {
        int64_t uid = [(NSNumber*)self.body longLongValue];
        writeInt64(uid, p);
        return [NSData dataWithBytes:buf length:HEAD_SIZE+8];
    } else if (self.cmd == MSG_VOIP_CONTROL) {
        VOIPControl *ctl = (VOIPControl*)self.body;
        writeInt64(ctl.sender, p);
        p += 8;
        writeInt64(ctl.receiver, p);
        p += 8;

        writeInt32(ctl.cmd, p);
        p += 4;
        if (ctl.cmd == VOIP_COMMAND_DIAL) {
            writeInt32(ctl.dialCount, p);
            p += 4;
            return [NSData dataWithBytes:buf length:HEAD_SIZE+24];
        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT || ctl.cmd == VOIP_COMMAND_CONNECTED) {
            NSLog(@"nat map ip:%x", ctl.natMap.ip);
            writeInt32(ctl.natMap.ip, p);
            p += 4;
            writeInt16(ctl.natMap.port, p);
            p += 2;
            return [NSData dataWithBytes:buf length:HEAD_SIZE+26];
        } else {
            return [NSData dataWithBytes:buf length:HEAD_SIZE+20];
        }
    } 
    return nil;
}

-(BOOL)unpack:(NSData*)data {
    const char *p = [data bytes];
    self.seq = readInt32(p);
    p += 4;
    self.cmd = *p;
    p += 4;
    NSLog(@"seq:%d cmd:%d", self.seq, self.cmd);
    if (self.cmd == MSG_RST) {
        return YES;
    } else if (self.cmd == MSG_AUTH_STATUS) {
        int status = readInt32(p);
        self.body = [NSNumber numberWithInt:status];
        return YES;
    } else if (self.cmd == MSG_VOIP_CONTROL) {
        VOIPControl *ctl = [[VOIPControl alloc] init];
        ctl.sender = readInt64(p);
        p += 8;
        ctl.receiver = readInt64(p);
        p += 8;
        ctl.cmd = readInt32(p);
        p += 4;
        if (ctl.cmd == VOIP_COMMAND_DIAL) {
            ctl.dialCount = readInt32(p);
        } else if (ctl.cmd == VOIP_COMMAND_ACCEPT || ctl.cmd == VOIP_COMMAND_CONNECTED) {
            if (data.length >= HEAD_SIZE + 26) {
                ctl.natMap = [[NatPortMap alloc] init];
                ctl.natMap.ip = readInt32(p);
                p += 4;
                ctl.natMap.port = readInt16(p);
                p += 2;
            }
        }
        self.body = ctl;
        return YES;
    }
    return NO;
}

@end
