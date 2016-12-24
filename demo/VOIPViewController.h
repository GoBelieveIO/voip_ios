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

@class VOIPEngine;
@class VOIPSession;
@class RTCPeerConnectionFactory;
@class RTCPeerConnection;

@interface VOIPViewController : WebRTCViewController<AVAudioPlayerDelegate, RTMessageObserver>

@property(nonatomic) VOIPSession *voip;

@property(nonatomic) int64_t currentUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *peerName;
@property(nonatomic, copy) NSString *token;


-(int)setLoudspeakerStatus:(BOOL)enable;
-(void)dismiss;

-(void)dial;
-(void)waitAccept;

@end
