#include <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVTransport.h"

@interface AudioReceiveStream : NSObject
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property(assign, nonatomic)int voiceChannel;

@property (assign, nonatomic) BOOL isHeadphone;
@property (assign, nonatomic) BOOL isLoudspeaker;


-(BOOL)start;
-(BOOL)stop;
@end

@class VOIPRenderView;

@interface AVReceiveStream : NSObject {
    
}
@property (weak, nonatomic) VOIPRenderView *render;
@property (assign) uint64_t uid;
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property (assign, nonatomic) int voiceChannel;
@property (nonatomic) int32_t localVideoSSRC;
@property (nonatomic) int32_t remoteVideoSSRC;

@property (nonatomic) int32_t localVoiceSSRC;
@property (nonatomic) int32_t remoteVoiceSSRC;

-(void)setCall:(void*)call;

-(BOOL)start;
-(BOOL)stop;
@end

