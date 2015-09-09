//
//  VOIPViewController.h
//  Face
//
//  Created by houxh on 14-10-13.
//  Copyright (c) 2014年 beetle. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class VOIPEngine;
@class VOIPSession;

@interface VOIPViewController : UIViewController<AVAudioPlayerDelegate>
@property(nonatomic) int64_t currentUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *peerName;
@property(nonatomic, copy) NSString *token;
//当前用户是否是主动呼叫方
@property(nonatomic) BOOL isCaller;


@property(nonatomic) VOIPEngine *engine;
@property(nonatomic) VOIPSession *voip;


-(BOOL)isP2P;
-(int)SetLoudspeakerStatus:(BOOL)enable;

@end
