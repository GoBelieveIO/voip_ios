//
//  VOIPVoiceViewController.m
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//
#import "VOIPVoiceViewController.h"
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



@interface VOIPVoiceViewController ()<RTCPeerConnectionDelegate, RTMessageObserver>
@property(nonatomic) BOOL shouldUseLevelControl;
@property(nonatomic) BOOL isLoopback;
@end

@implementation VOIPVoiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
 
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dial {
    [self.voip dial];
}

- (void)startStream {
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
    
    
    if (self.isCaller) {
        // Send offer.
        __weak VOIPVoiceViewController *weakSelf = self;
        [self.peerConnection offerForConstraints:[self defaultOfferConstraints]
                           completionHandler:^(RTCSessionDescription *sdp,
                                               NSError *error) {
                               VOIPVoiceViewController *strongSelf = weakSelf;
                               [strongSelf peerConnection:strongSelf.peerConnection
                              didCreateSessionDescription:sdp
                                                    error:error];
                           }];
    } else {
        // Check if we've received an offer.
//        [self drainMessageQueueIfReady];
    }
    
//#if defined(WEBRTC_IOS)
//    // Start event log.
//    if (kARDAppClientEnableRtcEventLog) {
//        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-rtceventlog"];
//        if (![_peerConnection startRtcEventLogWithFilePath:filePath
//                                            maxSizeInBytes:kARDAppClientRtcEventLogMaxSizeInBytes]) {
//            RTCLogError(@"Failed to start event logging.");
//        }
//    }
//    
//    // Start aecdump diagnostic recording.
//    if (_shouldMakeAecDump) {
//        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-audio.aecdump"];
//        if (![_factory startAecDumpWithFilePath:filePath
//                                 maxSizeInBytes:kARDAppClientAecDumpMaxSizeInBytes]) {
//            RTCLogError(@"Failed to start aec dump.");
//        }
//    }
//#endif
    
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"OfferToReceiveAudio" : @"true",
                                           @"OfferToReceiveVideo" : @"false"
                                           };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    NSString *value = self.isLoopback ? @"false" : @"true";
    NSDictionary *optionalConstraints = @{ @"DtlsSrtpKeyAgreement" : value , @"video":@"false"};
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
- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSString *valueLevelControl = _shouldUseLevelControl ?
    kRTCMediaConstraintsValueTrue : kRTCMediaConstraintsValueFalse;
    NSDictionary *mandatoryConstraints = @{ kRTCMediaConstraintsLevelControl : valueLevelControl };
    RTCMediaConstraints *constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}


-(void)stopStream {
    NSLog(@"stop stream");
    //    [self.factory stopAecDump];
//    [self.peerConnection stopRtcEventLog];
    self.peerConnection = nil;
    RTCStopInternalCapture();
}



- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
            NSLog(@"sdp error:%@", sdpError);
//            [_delegate appClient:self didError:sdpError];
            return;
        }
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        if (!self.isCaller && !self.peerConnection.localDescription) {
            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
            __weak VOIPVoiceViewController *weakSelf = self;
            [self.peerConnection answerForConstraints:constraints
                                completionHandler:^(RTCSessionDescription *sdp,
                                                    NSError *error) {
                                    VOIPVoiceViewController *strongSelf = weakSelf;
                                    [strongSelf peerConnection:strongSelf.peerConnection
                                   didCreateSessionDescription:sdp
                                                         error:error];
                                }];
        }
    });
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
        __weak VOIPVoiceViewController *weakSelf = self;
        [self.peerConnection setLocalDescription:sdpPreferringH264
                               completionHandler:^(NSError *error) {
                                   VOIPVoiceViewController *strongSelf = weakSelf;
                                   [strongSelf peerConnection:strongSelf.peerConnection
                            didSetSessionDescriptionWithError:error];
                                   
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
        __weak VOIPVoiceViewController *weakSelf = self;
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
                                                                        VOIPVoiceViewController *strongSelf = weakSelf;
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
//            [_delegate appClient:self didReceiveRemoteVideoTrack:videoTrack];
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
