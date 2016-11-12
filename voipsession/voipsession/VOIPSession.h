/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <Foundation/Foundation.h>
#import "VOIPService.h"
#import "VOIPCommand.h"

//todo 状态变迁图
enum VOIPState {
    VOIP_LISTENING,
    VOIP_DIALING,//呼叫对方
    VOIP_CONNECTED,//通话连接成功
    VOIP_ACCEPTING,//询问用户是否接听来电
    VOIP_ACCEPTED,//用户接听来电
    VOIP_REFUSING,//来电被拒
    VOIP_REFUSED,//(来/去)电已被拒
    VOIP_HANGED_UP,//通话被挂断
    VOIP_SHUTDOWN,//对方正在通话中，连接被终止
};

@protocol VOIPSessionDelegate <NSObject>
@required
-(void)onRefuse;
-(void)onHangUp;
-(void)onTalking;

-(void)onDialTimeout;
-(void)onAcceptTimeout;
-(void)onConnected;
-(void)onRefuseFinished;
@end

@interface VOIPSession : NSObject<VOIPObserver>


@property(nonatomic, weak) NSObject<VOIPSessionDelegate> *delegate;

@property(nonatomic, assign) enum VOIPState state;

@property(nonatomic, assign) int64_t currentUID;
@property(nonatomic, assign) int64_t peerUID;




-(void)dial;
-(void)dialVideo;
-(void)accept;
-(void)refuse;
-(void)hangUp;
@end
