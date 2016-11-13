//
//  WebRTCViewController.h
//  voip_demo
//
//  Created by houxh on 2016/11/13.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebRTC/WebRTC.h>

#import <voipsession/VOIPSession.h>

@interface WebRTCViewController : UIViewController<RTMessageObserver>
@property(nonatomic) int64_t currentUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *peerName;
@property(nonatomic, copy) NSString *token;
//当前用户是否是主动呼叫方
@property(nonatomic) BOOL isCaller;

@property(nonatomic, assign) BOOL isAudioOnly;


@property(nonatomic, strong) RTCPeerConnectionFactory *factory;

@property(nonatomic, strong) RTCPeerConnection *peerConnection;



@property(nonatomic, strong) RTCVideoTrack *localVideoTrack;
@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;

@property(nonatomic, weak) RTCEAGLVideoView *remoteVideoView;
@property(nonatomic, weak) RTCCameraPreviewView *localVideoView;

- (void)startStream;
- (void)stopStream;
@end
