//
//  VOIPEngine.h
//  Face
//
//  Created by houxh on 15/3/8.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface VOIPEngine : NSObject
@property(nonatomic)int voipPort;

@property(nonatomic, copy) NSString *serverIP;

@property(nonatomic)int64_t caller;

@property(nonatomic)int64_t callee;
@property(nonatomic)int32_t calleeIP;
@property(nonatomic)int calleePort;

-(void)startStream:(BOOL)isHeadphone;
-(void)stopStream;
@end
