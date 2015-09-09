/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <Foundation/Foundation.h>
#import "VOIPMessage.h"

#define STATE_UNCONNECTED 0
#define STATE_CONNECTING 1
#define STATE_CONNECTED 2
#define STATE_CONNECTFAIL 3


@protocol VOIPObserver <NSObject>

-(void)onVOIPControl:(VOIPControl*)ctl;


@end

@protocol VOIPConnectObserver <NSObject>

//同IM服务器连接的状态变更通知
-(void)onConnectState:(int)state;

@end

@interface VOIPService : NSObject

@property(nonatomic, copy) NSString* relayIP;
@property(nonatomic, copy) NSString *host;

@property(nonatomic, copy) NSString *deviceID;
@property(nonatomic, copy) NSString *token;
@property(nonatomic, assign) int connectState;

+(VOIPService*)instance;

-(void)startRechabilityNotifier;

-(void)start;
-(void)stop;
-(void)enterForeground;
-(void)enterBackground;

-(void)addMessageObserver:(id<VOIPConnectObserver>)ob;
-(void)removeMessageObserver:(id<VOIPConnectObserver>)ob;

-(void)pushVOIPObserver:(id<VOIPObserver>)ob;
-(void)popVOIPObserver:(id<VOIPObserver>)ob;

-(BOOL)sendVOIPControl:(VOIPControl*)ctl;
@end

