/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class VOIPEngine;
@class VOIPSession;
@class RTCPeerConnectionFactory;
@class RTCPeerConnection;

@interface VOIPViewController : UIViewController<AVAudioPlayerDelegate>
@property(nonatomic) int64_t currentUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *peerName;
@property(nonatomic, copy) NSString *token;
//当前用户是否是主动呼叫方
@property(nonatomic) BOOL isCaller;

@property(nonatomic) VOIPSession *voip;

@property(nonatomic, strong) RTCPeerConnectionFactory *factory;

@property(nonatomic, strong) RTCPeerConnection *peerConnection;


-(int)SetLoudspeakerStatus:(BOOL)enable;
-(void)dismiss;
@end
