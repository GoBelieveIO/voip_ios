//
//  VOIPVideoViewController.m
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "VOIPVideoViewController.h"

#include <arpa/inet.h>
#import <AVFoundation/AVAudioSession.h>
#import <UIKit/UIKit.h>
#import <voipsession/VOIPSession.h>

#import <WebRTC/WebRTC.h>
#import "ARDSDPUtils.h"

#import "ARDSignalingMessage.h"




static NSString * const kARDDefaultSTUNServerUrl =
@"stun:stun.l.google.com:19302";
// TODO(tkchin): figure out a better username for CEOD statistics.
static NSString * const kARDTurnRequestUrl =
@"https://computeengineondemand.appspot.com"
@"/turn?username=iapprtc&key=4080218913";

static NSString * const kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger const kARDAppClientErrorUnknown = -1;
static NSInteger const kARDAppClientErrorRoomFull = -2;
static NSInteger const kARDAppClientErrorCreateSDP = -3;
static NSInteger const kARDAppClientErrorSetSDP = -4;
static NSInteger const kARDAppClientErrorInvalidClient = -5;
static NSInteger const kARDAppClientErrorInvalidRoom = -6;
static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";



@interface VOIPVideoViewController ()<RTCEAGLVideoViewDelegate, RTCPeerConnectionDelegate>
@property(nonatomic) BOOL shouldUseLevelControl;
@property(nonatomic) BOOL isLoopback;

@property(nonatomic, strong) RTCVideoTrack *localVideoTrack;
@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;

@property(nonatomic, weak) RTCEAGLVideoView *remoteVideoView;
@property(nonatomic, weak) RTCCameraPreviewView *localVideoView;
@end

@implementation VOIPVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    
    
    UIButton *switchButton = [[UIButton alloc] initWithFrame:CGRectMake(240, 50, 80, 40)];
    
    [switchButton setTitle:@"切换" forState:UIControlStateNormal];
    [switchButton addTarget:self
                     action:@selector(switchCamera:)
           forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:switchButton];
    
    
    RTCEAGLVideoView *remoteVideoView = [[RTCEAGLVideoView alloc] initWithFrame:self.view.bounds];
    remoteVideoView.delegate = self;
    
    self.remoteVideoView = remoteVideoView;
    [self.view insertSubview:self.remoteVideoView atIndex:0];
    
    RTCCameraPreviewView *localVideoView = [[RTCCameraPreviewView alloc] initWithFrame:CGRectMake(200, 380, 72, 96)];
    self.localVideoView = localVideoView;
    [self.view insertSubview:self.localVideoView aboveSubview:self.remoteVideoView];

    

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)switchCamera:(id)sender {
    NSLog(@"switch camera");
    
    RTCVideoSource* source = self.localVideoTrack.source;
    if ([source isKindOfClass:[RTCAVFoundationVideoSource class]]) {
        RTCAVFoundationVideoSource* avSource = (RTCAVFoundationVideoSource*)source;
        avSource.useBackCamera = !avSource.useBackCamera;
    }
}

- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    
}
/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
-(void)dismiss {
    [super dismiss];
}

- (void)dial {
    [self.voip dialVideo];
}

#pragma mark - Private

- (void)setLocalVideoTrack:(RTCVideoTrack *)localVideoTrack {
    if (_localVideoTrack == localVideoTrack) {
        return;
    }
    _localVideoTrack = nil;
    _localVideoTrack = localVideoTrack;
    RTCAVFoundationVideoSource *source = nil;
    if ([localVideoTrack.source
         isKindOfClass:[RTCAVFoundationVideoSource class]]) {
        source = (RTCAVFoundationVideoSource*)localVideoTrack.source;
    }
    self.localVideoView.captureSession = source.captureSession;
}

- (void)setRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack {
    if (_remoteVideoTrack == remoteVideoTrack) {
        return;
    }
    [_remoteVideoTrack removeRenderer:self.remoteVideoView];
    _remoteVideoTrack = nil;
    [self.remoteVideoView renderFrame:nil];
    _remoteVideoTrack = remoteVideoTrack;
    [_remoteVideoTrack addRenderer:self.remoteVideoView];
}


- (void)startStream {
    if (self.voip.localNatMap != nil) {
        struct in_addr addr;
        addr.s_addr = htonl(self.voip.localNatMap.ip);
        NSLog(@"local nat map:%s:%d", inet_ntoa(addr), self.voip.localNatMap.port);
    }
    if (self.voip.peerNatMap != nil) {
        struct in_addr addr;
        addr.s_addr = htonl(self.voip.peerNatMap.ip);
        NSLog(@"peer nat map:%s:%d", inet_ntoa(addr), self.voip.peerNatMap.port);
    }
    
    if (self.isP2P) {
        struct in_addr addr;
        addr.s_addr = htonl(self.voip.peerNatMap.ip);
        NSLog(@"peer address:%s:%d", inet_ntoa(addr), self.voip.peerNatMap.port);
        NSLog(@"start p2p stream");
    } else {
        NSLog(@"start stream");
    }

    
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    

    
    [self SetLoudspeakerStatus:YES];
    
    
    
    
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    RTCIceServer *server = [[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.counterpath.net:3478"]];
    NSString *username = @"hxh:123456";
    NSString *credential = @"";
    
    RTCIceServer *server2 = [[RTCIceServer alloc] initWithURLStrings:@[@"turn:192.168.1.106:3478?transport=udp"]
                                                            username:username
                                                          credential:credential];
    config.iceServers =  @[server, server2];
    self.peerConnection = [self.factory peerConnectionWithConfiguration:config
                                                            constraints:constraints
                                                               delegate:self];
    
    // Create AV senders.
    [self createAudioSender];
    [self createVideoSender];
    
    if (self.isCaller) {
        // Send offer.
        __weak VOIPVideoViewController *weakSelf = self;
        [self.peerConnection offerForConstraints:[self defaultOfferConstraints]
                               completionHandler:^(RTCSessionDescription *sdp,
                                                   NSError *error) {
                                   VOIPVideoViewController *strongSelf = weakSelf;
                                   [strongSelf peerConnection:strongSelf.peerConnection
                                  didCreateSessionDescription:sdp
                                                        error:error];
                               }];
    }
}


-(void)stopStream {
    NSLog(@"stop stream");
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    self.peerConnection = nil;
    RTCStopInternalCapture();
}


- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"true"
                                           };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSString *value = self.isLoopback ? @"false" : @"true";
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : value , @"video":@"true", @"audio":@"true"};
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCRtpSender *)createAudioSender {
    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [self.factory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [self.factory audioTrackWithSource:source
                                                      trackId:kARDAudioTrackId];
    RTCRtpSender *sender =
    [self.peerConnection senderWithKind:kRTCMediaStreamTrackKindAudio
                               streamId:kARDMediaStreamId];
    sender.track = track;
    return sender;
}


- (RTCRtpSender *)createVideoSender {
    RTCRtpSender *sender =
    [self.peerConnection senderWithKind:kRTCMediaStreamTrackKindVideo
                           streamId:kARDMediaStreamId];
    RTCVideoTrack *track = [self createLocalVideoTrack];
    if (track) {
        sender.track = track;
        self.localVideoTrack = track;
    }
    return sender;
}


- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
#if !TARGET_IPHONE_SIMULATOR

        RTCMediaConstraints *cameraConstraints =
        [self cameraConstraints];
        RTCAVFoundationVideoSource *source =
        [self.factory avFoundationVideoSourceWithConstraints:cameraConstraints];
        localVideoTrack =
        [self.factory videoTrackWithSource:source
                               trackId:kARDVideoTrackId];

#endif
    return localVideoTrack;
}

- (RTCMediaConstraints *)cameraConstraints {
    NSDictionary *mediaConstraintsDictionary = @{
                                   kRTCMediaConstraintsMinWidth : @"640",
                                   kRTCMediaConstraintsMinHeight : @"480"
                                   };
    
    RTCMediaConstraints *cameraConstraints = [[RTCMediaConstraints alloc]
                                              initWithMandatoryConstraints:nil
                                              optionalConstraints: mediaConstraintsDictionary];
                                                                   
    return cameraConstraints;
}


- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSString *valueLevelControl = _shouldUseLevelControl ?
    kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse;
    NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : valueLevelControl };
    RTCMediaConstraints *constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}





- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorCreateSDP
                                   userInfo:userInfo];
            NSLog(@"sdp error:%@", sdpError);
            //[_delegate appClient:self didError:sdpError];
            return;
        }
        // Prefer H264 if available.
        RTCSessionDescription *sdpPreferringH264 =
        [ARDSDPUtils descriptionForDescription:sdp
                           preferredVideoCodec:@"H264"];
        [self.peerConnection setLocalDescription:sdpPreferringH264
                               completionHandler:^(NSError *error) {
                        
                                   
                               }];
        
        NSLog(@"sdp description:%@", sdpPreferringH264);
        
        ARDSessionDescriptionMessage *message = [[ARDSessionDescriptionMessage alloc] initWithDescription:sdpPreferringH264];
        [self sendSignalingMessage:message];
    });
}


-(void)onRTMessage:(RTMessage*)rt {
    if (rt.sender != self.peerUID) {
        return;
    }
    
    ARDSignalingMessage *message = [ARDSignalingMessage messageFromJSONString:rt.content];
    
    NSLog(@"recv signal message:%@", rt.content);
    [self processMessage:message];
}

- (void)processMessage:(ARDSignalingMessage*)message {
    if (message.type == kARDSignalingMessageTypeCandidate) {
        ARDICECandidateMessage *candidateMessage =
        (ARDICECandidateMessage *)message;
        [self.peerConnection addIceCandidate:candidateMessage.candidate];
    } else if (message.type == kARDSignalingMessageTypeCandidateRemoval) {
        ARDICECandidateRemovalMessage *candidateMessage = (ARDICECandidateRemovalMessage *)message;
        [self.peerConnection removeIceCandidates:candidateMessage.candidates];
    } else if (message.type == kARDSignalingMessageTypeOffer) {
        ARDSessionDescriptionMessage *descMsg = (ARDSessionDescriptionMessage*)message;
        RTCSessionDescription *description = descMsg.sessionDescription;
        // Prefer H264 if available.
        RTCSessionDescription *sdpPreferringH264 =
        [ARDSDPUtils descriptionForDescription:description
                           preferredVideoCodec:@"H264"];
        __weak VOIPVideoViewController *weakSelf = self;
        [self.peerConnection setRemoteDescription:sdpPreferringH264
                                completionHandler:^(NSError *error) {
                                    if (error) {
                                        NSLog(@"error:%@", error);
                                        return;
                                    }
                                    
                                    if (weakSelf && !weakSelf.isCaller) {
                                        RTCMediaConstraints *constraints = [weakSelf defaultAnswerConstraints];
                                        [weakSelf.peerConnection answerForConstraints:constraints
                                                                    completionHandler:^(RTCSessionDescription *sdp,
                                                                                        NSError *error) {
                                                                        VOIPVideoViewController *strongSelf = weakSelf;
                                                                        [strongSelf peerConnection:strongSelf.peerConnection
                                                                       didCreateSessionDescription:sdp
                                                                                             error:error];
                                                                    }];
                                    }
                                }];
    } else if (message.type == kARDSignalingMessageTypeAnswer) {
        ARDSessionDescriptionMessage *descMsg = (ARDSessionDescriptionMessage*)message;
        RTCSessionDescription *description = descMsg.sessionDescription;
        // Prefer H264 if available.
        RTCSessionDescription *sdpPreferringH264 =
        [ARDSDPUtils descriptionForDescription:description
                           preferredVideoCodec:@"H264"];
        [self.peerConnection setRemoteDescription:sdpPreferringH264
                                completionHandler:^(NSError *error) {
                                    if (error) {
                                        NSLog(@"error:%@", error);
                                        return;
                                    }
                                }];
        
    }
}


- (void)sendSignalingMessage:(ARDSignalingMessage*)msg {
    NSData *data = [msg JSONData];
    
    
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSLog(@"send signal message:%@", str);
    
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;
    rt.content = str;
    [[VOIPService instance] sendRTMessage:rt];
}


#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %ld", (long)stateChanged);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Received %lu video tracks and %lu audio tracks",
              (unsigned long)stream.videoTracks.count,
              (unsigned long)stream.audioTracks.count);
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            NSLog(@"did receive remote video track");
            self.remoteVideoTrack = videoTrack;
        }
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState {
    NSLog(@"ICE state changed: %ld", (long)newState);
    dispatch_async(dispatch_get_main_queue(), ^{
        //        [_delegate appClient:self didChangeConnectionState:newState];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState {
    NSLog(@"ICE gathering state changed: %ld", (long)newState);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateMessage *message =
        [[ARDICECandidateMessage alloc] initWithCandidate:candidate];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    dispatch_async(dispatch_get_main_queue(), ^{
        ARDICECandidateRemovalMessage *message =
        [[ARDICECandidateRemovalMessage alloc]
         initWithRemovedCandidates:candidates];
        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {
}





@end
