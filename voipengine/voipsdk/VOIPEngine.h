//
//  VOIPEngine.h
//  Face
//
//  Created by houxh on 15/3/8.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import <Foundation/Foundation.h>
@class VOIPRenderView;

@interface VOIPEngine : NSObject
@property(nonatomic)int voipPort;

@property(nonatomic, copy) NSString *relayIP;
@property(nonatomic, copy) NSString *token;


@property(nonatomic)int64_t caller;

@property(nonatomic)int64_t callee;
@property(nonatomic)int32_t calleeIP;
@property(nonatomic)int calleePort;
@property(nonatomic)BOOL isHeadphone;
//当前用户是呼叫方
@property(nonatomic)BOOL isCaller;

@property(nonatomic)VOIPRenderView *render;
-(void)startStream;
-(void)stopStream;
@end
