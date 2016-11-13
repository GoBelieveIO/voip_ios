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





@interface VOIPVoiceViewController ()

@end

@implementation VOIPVoiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.isAudioOnly = YES;
    
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if(audioAuthStatus == AVAuthorizationStatusAuthorized) {
        if (self.isCaller) {
            [self dial];
        } else {
            [self waitAccept];
        }
    } else if(audioAuthStatus == AVAuthorizationStatusDenied){
    } else if(audioAuthStatus == AVAuthorizationStatusRestricted){
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
}

- (void)dial {
    [super dial];
    [self.voip dial];
}

- (void)startStream {
    [self setLoudspeakerStatus:NO];
    [super startStream];
}

@end
