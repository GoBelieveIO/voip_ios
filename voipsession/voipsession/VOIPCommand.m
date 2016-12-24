//
//  VOIPCommand.m
//  voipsession
//
//  Created by houxh on 16/2/2.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import "VOIPCommand.h"
#import <imsdk/util.h>

@implementation VOIPCommand
-(VOIPCommand*)initWithContent:(NSData*)content {
    self = [super init];
    if (self) {
        const char *p = [content bytes];
        self.cmd = readInt32(p);
        p += 4;
        if (content.length >= 12) {
            self.channelID = readInt64(p);
        }
     }
    return self;
}

-(NSData*)content {
    char buf[64*1024] = {0};
    char *p = buf;
    writeInt32(self.cmd, p);
    p += 4;
    writeInt64(self.channelID, p);
    return [NSData dataWithBytes:buf length:12];
}
@end
