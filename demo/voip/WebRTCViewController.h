//
//  WebRTCViewController.h
//  voip_demo
//
//  Created by houxh on 2016/11/13.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebRTC/WebRTC.h>

#import "ARDSignalingMessage.h"

@interface WebRTCViewController : UIViewController
//当前用户是否是主动呼叫方
@property(nonatomic) BOOL isCaller;
@property(nonatomic, assign) BOOL isAudioOnly;

@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) RTCPeerConnection *peerConnection;

@property(nonatomic, strong) RTCVideoTrack *localVideoTrack;
@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;

@property(nonatomic, weak) RTCEAGLVideoView *remoteVideoView;
@property(nonatomic, weak) RTCCameraPreviewView *localVideoView;

@property(nonatomic, copy) NSString *turnUserName;
@property(nonatomic, copy) NSString *turnPassword;

- (void)sendSignalingMessage:(ARDSignalingMessage*)msg;
- (void)processMessage:(ARDSignalingMessage*)message;

- (void)startStream;
- (void)stopStream;
@end
