/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "WebRTCViewController.h"
#import "VOIPService.h"

#define APPID 7
@interface VOIPViewController : WebRTCViewController<AVAudioPlayerDelegate, RTMessageObserver>
+(int64_t)controllerCount;

@property(nonatomic) BOOL isConnected;

@property(nonatomic) int64_t currentUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *token;
@property(nonatomic) NSString *channelID;

-(int)setLoudspeakerStatus:(BOOL)enable;
-(void)dismiss;

-(void)playDialOut;

-(void)dialVoice;
-(void)dialVideo;
-(void)accept;
-(void)refuse;
-(void)hangUp;
-(void)onConnected;
@end
