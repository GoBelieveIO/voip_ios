//
//  VOIPCommand.m
//  voipsession
//
//  Created by houxh on 16/2/2.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import "VOIPCommand.h"
#import <imsdk/util.h>

@implementation NatPortMap

@end

@implementation VOIPCommand
-(VOIPCommand*)initWithContent:(NSData*)content {
    self = [super init];
    if (self) {
        const char *p = [content bytes];
        self.cmd = readInt32(p);
        p += 4;
        if (self.cmd == VOIP_COMMAND_DIAL || self.cmd == VOIP_COMMAND_DIAL_VIDEO) {
            self.dialCount = readInt32(p);
        } else if (self.cmd == VOIP_COMMAND_ACCEPT) {
            if (content.length >= 10) {
                self.natMap = [[NatPortMap alloc] init];
                self.natMap.ip = readInt32(p);
                p += 4;
                self.natMap.port = readInt16(p);
                p += 2;
            }
        } else if (self.cmd == VOIP_COMMAND_CONNECTED) {
            if (content.length >= 10) {
                self.natMap = [[NatPortMap alloc] init];
                self.natMap.ip = readInt32(p);
                p += 4;
                self.natMap.port = readInt16(p);
                p += 2;
            }
            if (content.length >= 14) {
                self.relayIP = readInt32(p);
                p += 4;
            }
        }
    }
    return self;
}

-(NSData*)content {
    char buf[64*1024] = {0};
    char *p = buf;
    
    writeInt32(self.cmd, p);
    p += 4;
    if (self.cmd == VOIP_COMMAND_DIAL || self.cmd == VOIP_COMMAND_DIAL_VIDEO) {
        writeInt32(self.dialCount, p);
        p += 4;
        return [NSData dataWithBytes:buf length:8];
    } else if (self.cmd == VOIP_COMMAND_ACCEPT) {
        NSLog(@"nat map ip:%x", self.natMap.ip);
        writeInt32(self.natMap.ip, p);
        p += 4;
        writeInt16(self.natMap.port, p);
        p += 2;
        return [NSData dataWithBytes:buf length:10];
    } else if (self.cmd == VOIP_COMMAND_CONNECTED) {
        NSLog(@"nat map ip:%x", self.natMap.ip);
        writeInt32(self.natMap.ip, p);
        p += 4;
        writeInt16(self.natMap.port, p);
        p += 2;
        writeInt32(self.relayIP, p);
        p += 4;
        return [NSData dataWithBytes:buf length:14];
    } else {
        return [NSData dataWithBytes:buf length:4];
    }
}
@end
