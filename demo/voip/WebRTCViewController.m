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
#import "ARDCaptureController.h"

static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";


@interface WebRTCViewController ()<RTCPeerConnectionDelegate>
@property(nonatomic) BOOL shouldUseLevelControl;
@property(nonatomic) ARDCaptureController *captureController;
@end

@implementation WebRTCViewController

-(BOOL)videoEnabled {
    return !self.isAudioOnly;
}

-(void)setVideoEnabled:(BOOL)videoEnabled {
    self.isAudioOnly = !videoEnabled;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
    RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
    self.factory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                             decoderFactory:decoderFactory];
}


#pragma mark - Private
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

- (void)toogleVideo {
    self.videoEnabled = !self.videoEnabled;
    self.remoteVideoTrack.isEnabled = self.videoEnabled;
    self.localVideoTrack.isEnabled =  self.videoEnabled;
}

-(void)switchCamera:(id)sender {
    NSLog(@"switch camera");
    [self.captureController switchCamera];
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
    
    [self createMediaSenders];
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
    BOOL isLoopback = NO;
    NSString *value = isLoopback ? @"false" : @"true";
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : value , @"video":@"true", @"audio":@"true"};
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}

- (void)createMediaSenders {
    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [self.factory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [self.factory audioTrackWithSource:source
                                                  trackId:kARDAudioTrackId];
    [self.peerConnection addTrack:track streamIds:@[ kARDMediaStreamId ]];
    self.localVideoTrack = [self createLocalVideoTrack];
    if (self.localVideoTrack) {
        [self.peerConnection addTrack:self.localVideoTrack streamIds:@[ kARDMediaStreamId ]];
    }
}

- (RTCVideoTrack *)createLocalVideoTrack {
    RTCVideoTrack* localVideoTrack = nil;
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
#if !TARGET_IPHONE_SIMULATOR
    
    if (!self.isAudioOnly) {
        RTCVideoSource *source = [self.factory videoSource];
        RTCCameraVideoCapturer *capturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:source];
        self.localVideoView.captureSession = capturer.captureSession;
        self.captureController = [[ARDCaptureController alloc] initWithCapturer:capturer with:640 height:480 fps:30];
        [self.captureController startCapture];

        localVideoTrack = [self.factory videoTrackWithSource:source
                                                     trackId:kARDVideoTrackId];
    }
    
#endif
    return localVideoTrack;
}


- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{};
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
        [self.peerConnection setLocalDescription:sdp
                               completionHandler:^(NSError *error) {
                                   
                                   
                               }];
        
        NSLog(@"sdp description:%@", sdp);
        
        ARDSessionDescriptionMessage *message = [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
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
        __weak WebRTCViewController *weakSelf = self;
        [self.peerConnection setRemoteDescription:description
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
        [self.peerConnection setRemoteDescription:description
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


