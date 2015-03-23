//
//  VOIP.h
//  Face
//
//  Created by houxh on 14-10-13.
//  Copyright (c) 2014年 beetle. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "IMService.h"

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
    VOIP_RESETED,//通话连接被重置
};

@protocol VOIPSessionDelegate <NSObject>
-(void)onRefuse;
-(void)onHangUp;
-(void)onReset;

-(void)onDialTimeout;
-(void)onAcceptTimeout;
-(void)onConnected;
-(void)onRefuseFinished;
@end

@interface VOIPSession : NSObject<VOIPObserver>


@property(nonatomic, weak) NSObject<VOIPSessionDelegate> *delegate;

@property(nonatomic, assign) enum VOIPState state;

@property(nonatomic, assign) int voipPort;
@property(nonatomic, copy) NSString *stunServer;
@property(nonatomic, assign) int64_t currentUID;
@property(nonatomic, assign) int64_t peerUID;

@property(nonatomic) NatPortMap *peerNatMap;
@property(nonatomic) NatPortMap *localNatMap;

-(void)holePunch;
-(void)dial;
-(void)accept;
-(void)refuse;
-(void)hangUp;
@end
