//
//  WebRTCViewController.m
//  voip_demo
//
//  Created by houxh on 2016/11/13.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import "WebRTCViewController.h"
#import <WebRTC/WebRTC.h>
#import "ARDSDPUtils.h"
#import "ARDSignalingMessage.h"


static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


@interface WebRTCViewController ()<RTCPeerConnectionDelegate>
@property(nonatomic) BOOL shouldUseLevelControl;
@property(nonatomic) BOOL isLoopback;
@end

@implementation WebRTCViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.factory = [[RTCPeerConnectionFactory alloc] init];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
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
    if (self.remoteVideoView) {
        [_remoteVideoTrack removeRenderer:self.remoteVideoView];
        _remoteVideoTrack = nil;
        [self.remoteVideoView renderFrame:nil];
    }
    _remoteVideoTrack = remoteVideoTrack;
    
    if (self.remoteVideoView) {
        [_remoteVideoTrack addRenderer:self.remoteVideoView];
    }
}


- (void)startStream {
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    RTCIceServer *server = [[RTCIceServer alloc] initWithURLStrings:@[@"stun:stun.counterpath.net:3478"]];

    
    NSString *username = self.turnUserName;
    NSString *credential = self.turnPassword;
    RTCIceServer *server2 = [[RTCIceServer alloc] initWithURLStrings:@[@"turn:turn.gobelieve.io:3478?transport=udp"]
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
        __weak WebRTCViewController *weakSelf = self;
        [self.peerConnection offerForConstraints:[self defaultOfferConstraints]
                               completionHandler:^(RTCSessionDescription *sdp,
                                                   NSError *error) {
                                   WebRTCViewController *strongSelf = weakSelf;
                                   [strongSelf peerConnection:strongSelf.peerConnection
                                  didCreateSessionDescription:sdp
                                                        error:error];
                               }];
    }
}



-(void)stopStream {
    NSLog(@"stop stream");
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    
    [self.peerConnection close];
    self.peerConnection = nil;
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
    
    if (!self.isAudioOnly) {
        RTCMediaConstraints *cameraConstraints =
        [self cameraConstraints];
        RTCAVFoundationVideoSource *source =
        [self.factory avFoundationVideoSourceWithConstraints:cameraConstraints];
        localVideoTrack =
        [self.factory videoTrackWithSource:source
                                   trackId:kARDVideoTrackId];
    }
    
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
        __weak WebRTCViewController *weakSelf = self;
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
                                                                        WebRTCViewController *strongSelf = weakSelf;
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
    NSLog(@"did open data channel");
}
@end


