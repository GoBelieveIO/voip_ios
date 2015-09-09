//
//  VOIPVoiceViewController.m
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "VOIPVoiceViewController.h"
#include <arpa/inet.h>
#import <AVFoundation/AVAudioSession.h>
#import <UIKit/UIKit.h>
#import <voipengine/VOIPEngine.h>
#import <voipengine/VOIPRenderView.h>
#import <voipsession/VOIPSession.h>


@interface VOIPVoiceViewController ()

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
    
    if (self.engine != nil) {
        return;
    }
    
    self.engine = [[VOIPEngine alloc] init];
    NSLog(@"relay ip:%@", self.voip.relayIP);
    self.engine.relayIP = self.voip.relayIP;
    self.engine.voipPort = self.voip.voipPort;
    self.engine.caller = self.currentUID;
    self.engine.callee = self.peerUID;
    self.engine.token = self.token;
    self.engine.isCaller = self.isCaller;
    self.engine.videoEnabled = NO;
    
    
    if (self.isP2P) {
        self.engine.calleeIP = self.voip.peerNatMap.ip;
        self.engine.calleePort = self.voip.peerNatMap.port;
    }
    
    [self.engine startStream];
    
    [self SetLoudspeakerStatus:NO];
}


-(void)stopStream {
    if (self.engine == nil) {
        return;
    }
    NSLog(@"stop stream");
    [self.engine stopStream];

}


@end
