/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import <Foundation/Foundation.h>
@class VOIPRenderView;

@interface VOIPEngine : NSObject
@property(nonatomic)int voipPort;

@property(nonatomic, copy) NSString *relayIP;
@property(nonatomic, copy) NSString *token;


@property(nonatomic)int64_t caller;

@property(nonatomic)int64_t callee;
@property(nonatomic)int32_t calleeIP;
@property(nonatomic)int calleePort;
//当前用户是呼叫方
@property(nonatomic)BOOL isCaller;

@property(nonatomic)BOOL videoEnabled;

@property(nonatomic)VOIPRenderView *localRender;
@property(nonatomic)VOIPRenderView *remoteRender;

-(void)switchCamera;
-(void)startStream;
-(void)stopStream;
@end
