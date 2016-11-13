//
//  VOIPVideoViewController.m
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "VOIPVideoViewController.h"
#import <VOIPSession/VOIPSession.h>

@interface VOIPVideoViewController ()<RTCEAGLVideoViewDelegate>

@end

@implementation VOIPVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.isAudioOnly = NO;
    
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
    
    
    
    
    
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if(authStatus == AVAuthorizationStatusAuthorized) {
        // do your logic
        AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if(audioAuthStatus == AVAuthorizationStatusAuthorized) {
            if (self.isCaller) {
                [self dial];
            } else {
                [self waitAccept];
            }
        } else if(audioAuthStatus == AVAuthorizationStatusDenied){
            // denied
        } else if(audioAuthStatus == AVAuthorizationStatusRestricted){
            // restricted, normally won't happen
        } else if(audioAuthStatus == AVAuthorizationStatusNotDetermined){
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                if (granted) {
                    if (self.isCaller) {
                        [self dial];
                    } else {
                        [self waitAccept];
                    }
                } else {
                    NSLog(@"can't grant record permission");
                }
            }];
            
        }
        
    } else if(authStatus == AVAuthorizationStatusDenied){
        // denied
    } else if(authStatus == AVAuthorizationStatusRestricted){
        // restricted, normally won't happen
    } else if(authStatus == AVAuthorizationStatusNotDetermined){
        // not determined?!
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if(granted){
                NSLog(@"Granted access to %@", AVMediaTypeVideo);
                AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
                if(audioAuthStatus == AVAuthorizationStatusAuthorized) {
                    if (self.isCaller) {
                        [self dial];
                    } else {
                        [self waitAccept];
                    }
                } else if(audioAuthStatus == AVAuthorizationStatusDenied){
                    // denied
                } else if(audioAuthStatus == AVAuthorizationStatusRestricted){
                    // restricted, normally won't happen
                } else if(audioAuthStatus == AVAuthorizationStatusNotDetermined){
                    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
                        if (granted) {
                            
                            if (self.isCaller) {
                                [self dial];
                            } else {
                                [self waitAccept];
                            }
                        } else {
                            NSLog(@"can't grant record permission");
                        }
                    }];
                }
            } else {
                NSLog(@"Not granted access to %@", AVMediaTypeVideo);
            }
        }];
    }
}


- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    
}

-(void)switchCamera:(id)sender {
    NSLog(@"switch camera");
    
    RTCVideoSource* source = self.localVideoTrack.source;
    if ([source isKindOfClass:[RTCAVFoundationVideoSource class]]) {
        RTCAVFoundationVideoSource* avSource = (RTCAVFoundationVideoSource*)source;
        avSource.useBackCamera = !avSource.useBackCamera;
    }
}

-(void)dismiss {
    [super dismiss];
}

- (void)dial {
    [super dial];
    [self.voip dialVideo];
}


- (void)startStream {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    [self setLoudspeakerStatus:YES];
    [super startStream];

}

- (void)stopStream {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
    [super stopStream];
}

@end
