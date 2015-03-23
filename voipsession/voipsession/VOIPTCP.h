//
//  AsyncTCP.h
//  im
//
//  Created by houxh on 14-6-26.
//  Copyright (c) 2014年 potato. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VOIPTCP;
typedef void(^ConnectCB)(VOIPTCP *tcp, int err);
typedef void(^ReadCB)(VOIPTCP *tcp, NSData *data, int err);
typedef void(^CloseCB)(VOIPTCP *tcp, int err);

@interface VOIPTCP : NSObject
-(BOOL)connect:(NSString*)host port:(int)port cb:(ConnectCB)cb;
-(void)close;
-(void)write:(NSData*)data;
-(void)startRead:(ReadCB)cb;
@end


