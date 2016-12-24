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
-(VOIPCommand*)initWithContent:(NSDictionary*)dict {
    self = [super init];
    if (self) {
        self.cmd = [[dict objectForKey:@"command"] intValue];
        self.channelID = [dict objectForKey:@"channel_id"];
     }
    return self;
}

-(NSDictionary*)jsonDictionary {
    NSDictionary *dict = @{ @"command":[NSNumber numberWithInt:self.cmd],
                            @"channel_id":self.channelID };
    return dict;
}
@end
