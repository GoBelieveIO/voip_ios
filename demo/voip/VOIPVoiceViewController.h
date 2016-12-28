//
//  VOIPVoiceViewController.h
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "CallViewController.h"

@interface VOIPVoiceViewController : CallViewController
@property(nonatomic, copy) NSString *peerName;
@property(nonatomic, copy) NSString *peerAvatar;
@end
