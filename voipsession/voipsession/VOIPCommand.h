//
//  VOIPCommand.h
//  voipsession
//
//  Created by houxh on 16/2/2.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import <Foundation/Foundation.h>
enum EVOIPCommand {
    //语音通话
    VOIP_COMMAND_DIAL = 1,
    VOIP_COMMAND_ACCEPT = 2,
    VOIP_COMMAND_CONNECTED = 3,
    VOIP_COMMAND_REFUSE = 4,
    VOIP_COMMAND_REFUSED = 5,
    VOIP_COMMAND_HANG_UP = 6,
    VOIP_COMMAND_RESET = 7,

    //通话中
    VOIP_COMMAND_TALKING = 8,
    
    //视频通话
    VOIP_COMMAND_DIAL_VIDEO = 9,
    
    VOIP_COMMAND_PING = 10,
};



@interface VOIPCommand : NSObject
-(VOIPCommand*)initWithContent:(NSData*)content;
@property(nonatomic, readonly) NSData *content;
@property(nonatomic, assign) int32_t cmd;
@property(nonatomic, assign) int64_t channelID;
@end
