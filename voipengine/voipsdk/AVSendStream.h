#include <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AVTransport.h"

@interface AudioSendStream : NSObject {
}

@property (weak, nonatomic) id<VoiceTransport> voiceTransport;

@property(assign, nonatomic)int voiceChannel;

-(BOOL)start;
-(BOOL)stop;
@end

@interface AVSendStream : NSObject {
}
@property (weak, nonatomic) UIView *render;
@property (weak, nonatomic) id<VoiceTransport> voiceTransport;
@property (weak, nonatomic) id<VideoTransport> videoTransport;
@property(assign, nonatomic)int voiceChannel;
@property(assign, nonatomic)int videoChannel;

@property (assign, nonatomic)BOOL hasVideo;

-(void)sendKeyFrame;
-(BOOL)start;
-(BOOL)stop;
@end

