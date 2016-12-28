/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import "VOIPViewController.h"
#import <WebRTC/WebRTC.h>
#import "UIView+Toast.h"
#import "ARDUtilities.h"
#import "VOIPCommand.h"

//todo 状态变迁图
enum VOIPState {
    VOIP_DIALING = 1,//呼叫对方
    VOIP_CONNECTED,//通话连接成功
    VOIP_ACCEPTING,//询问用户是否接听来电
    VOIP_ACCEPTED,//用户接听来电
    VOIP_REFUSED,//(来/去)电已被拒
    VOIP_HANGED_UP,//通话被挂断
    VOIP_SHUTDOWN,//对方正在通话中，连接被终止
};


enum SessionMode {
    SESSION_VOICE,
    SESSION_VIDEO,
};

@interface VOIPViewController ()
@property(nonatomic) AVAudioPlayer *player;

@property(nonatomic, assign) enum VOIPState state;
@property(nonatomic, assign) enum SessionMode mode;

@property(nonatomic, assign) time_t dialBeginTimestamp;
@property(nonatomic) NSTimer *dialTimer;

@property(nonatomic, assign) time_t acceptTimestamp;
@property(nonatomic) NSTimer *acceptTimer;

@property(nonatomic, assign) time_t lastPingTimestamp;
@property(nonatomic) NSTimer *pingTimer;

@property(atomic, copy) NSString *voipHostIP;
@property(atomic) BOOL refreshing;


-(void)close;

-(void)dialVoice;
-(void)dialVideo;
-(void)accept;
-(void)refuse;
-(void)hangUp;

@end

static int64_t g_controllerCount = 0;

@implementation VOIPViewController

+(int64_t)controllerCount {
    return g_controllerCount;
}


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}


-(void)dealloc {
    NSLog(@"voip view controller dealloc");
    g_controllerCount--;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    g_controllerCount++;

    [[VOIPService instance] addRTMessageObserver:self];
    
    int64_t appid = APPID;
    int64_t uid = self.currentUID;
    NSString *username = [NSString stringWithFormat:@"%lld_%lld", appid, uid];
    self.turnUserName = username;
    self.turnPassword = self.token;
    
    if (self.isCaller) {
        [self playDialOut];
        self.state = VOIP_DIALING;
    } else {
        [self playDialIn];
        self.state = VOIP_ACCEPTING;
    }
}

-(void)dismiss {
    [self.player stop];
    self.player = nil;

    [self close];
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:NO];
    [self dismissViewControllerAnimated:YES completion:^{
        [[VOIPService instance] removeRTMessageObserver:self];
    }];
}


- (void)startStream {
    [super startStream];
}


-(void)stopStream {
    [super stopStream];
}


-(int)setLoudspeakerStatus:(BOOL)enable {
    AVAudioSession* session = [AVAudioSession sharedInstance];
    NSString* category = session.category;
    AVAudioSessionCategoryOptions options = session.categoryOptions;
    // Respect old category options if category is
    // AVAudioSessionCategoryPlayAndRecord. Otherwise reset it since old options
    // might not be valid for this category.
    if ([category isEqualToString:AVAudioSessionCategoryPlayAndRecord]) {
        if (enable) {
            options |= AVAudioSessionCategoryOptionDefaultToSpeaker;
        } else {
            options &= ~AVAudioSessionCategoryOptionDefaultToSpeaker;
        }
    } else {
        options = AVAudioSessionCategoryOptionDefaultToSpeaker;
    }
    
    NSError* error = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:options
                   error:&error];
    if (error != nil) {
        NSLog(@"set loudspeaker err:%@", error);
        return -1;
    }
    
    return 0;
}

#pragma mark - AVAudioPlayerDelegate
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag {
    NSLog(@"player finished");
    if (!self.isConnected) {
        [self.player play];
    }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error {
    NSLog(@"player decode error");
}

-(void)playResource:(NSString*)name {
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:name];
    NSURL *u = [NSURL fileURLWithPath:path];
    self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:u error:nil];
    [self.player setDelegate:self];
    
    [self.player play];
}

-(void)playDialIn {
    [self setLoudspeakerStatus:YES];
    [self playResource:@"start.mp3"];
}

-(void)playDialOut {
    [self setLoudspeakerStatus:!self.isAudioOnly];
    [self playResource:@"call.mpd3"];
}


- (void)sendSignalingMessage:(ARDSignalingMessage*)msg {
    NSDictionary *d = [msg JSONDictionary];
    NSDictionary *p2p = @{@"p2p":d};
    NSData *data = [NSJSONSerialization dataWithJSONObject:p2p options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"send signal message:%@", str);
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;
    rt.content = str;
    [[VOIPService instance] sendRTMessage:rt];
}


-(void)onRTMessage:(RTMessage*)rt {
    if (rt.sender != self.peerUID) {
        return;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithJSONString:rt.content];
    if ([dict objectForKey:@"p2p"]) {
        NSLog(@"recv signal message:%@", rt.content);
        ARDSignalingMessage *message = [ARDSignalingMessage messageFromDictionary:dict[@"p2p"]];
        [self processMessage:message];
    } else if ([dict objectForKey:@"voip"]) {
        NSLog(@"recv voip message:%@", rt.content);
        [self processVOIPMessage:dict[@"voip"] sender:rt.sender];
    }
}

#pragma mark - VOIPStateDelegate
-(void)onRefuse {
    [self.player stop];
    self.player = nil;
    
    [self dismiss];
}

-(void)onHangUp {
    if (self.isConnected) {
        [self stopStream];
        [self dismiss];
    } else {
        [self.player stop];
        self.player = nil;
        [self dismiss];
    }
}

-(void)onTalking {
    [self.player stop];
    self.player = nil;
    
    [self.view makeToast:@"对方正在通话中!" duration:2.0 position:@"center"];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self dismiss];
    });
}

-(void)onDialTimeout {
    [self.player stop];
    self.player = nil;
    
    [self hangUp];
    [self dismiss];
}

-(void)onAcceptTimeout {
    [self dismiss];
}

-(void)onConnected {
    NSLog(@"call voip connected");
    self.isConnected = YES;
    
    [self.player stop];
    self.player = nil;

    [self startStream];
}

-(void)onDisconnect {
    [self stopStream];
    [self dismiss];
}


- (void)close {
    if (self.dialTimer && self.dialTimer.isValid) {
        [self.dialTimer invalidate];
        self.dialTimer = nil;
    }
    if (self.acceptTimer && self.acceptTimer.isValid) {
        [self.acceptTimer invalidate];
        self.acceptTimer = nil;
    }
    
    if (self.pingTimer && self.pingTimer.isValid) {
        [self.pingTimer invalidate];
        self.pingTimer = nil;
    }
}

- (void)sendDial {
    NSLog(@"dial...");
    if (self.mode == SESSION_VOICE) {
        [self sendControlCommand:VOIP_COMMAND_DIAL];
    } else if (self.mode == SESSION_VIDEO) {
        [self sendControlCommand:VOIP_COMMAND_DIAL_VIDEO];
    } else {
        NSAssert(NO, @"invalid session mode");
    }
    
    time_t now = time(NULL);
    if (now - self.dialBeginTimestamp >= 60) {
        NSLog(@"dial timeout");
        
        //ondialtimeout
        [self onDialTimeout];
    }
}

-(void)sendCommand:(VOIPCommand*)command {
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;
    
    NSDictionary *dict = @{@"voip":command.jsonDictionary};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    rt.content = s;
    
    [[VOIPService instance] sendRTMessage:rt];
}

-(void)sendControlCommand:(enum EVOIPCommand)cmd {
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = cmd;
    command.channelID = self.channelID;
    [self sendCommand:command];
}

-(void)sendRefused {
    [self sendControlCommand:VOIP_COMMAND_REFUSED];
}

-(void)sendTalking:(int64_t)receiver {
    RTMessage *rt = [[RTMessage alloc] init];
    rt.sender = self.currentUID;
    rt.receiver = self.peerUID;
    
    VOIPCommand *command = [[VOIPCommand alloc] init];
    command.cmd = VOIP_COMMAND_TALKING;
    command.channelID = self.channelID;
    
    NSDictionary *dict = @{@"voip":command.jsonDictionary};
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    rt.content = s;
    [[VOIPService instance] sendRTMessage:rt];
}

-(void)sendReset {
    [self sendControlCommand:VOIP_COMMAND_RESET];
}

-(void)sendConnected {
    [self sendControlCommand:VOIP_COMMAND_CONNECTED];
}

-(void)sendDialAccept {
    [self sendControlCommand:VOIP_COMMAND_ACCEPT];
    
    time_t now = time(NULL);
    if (now - self.acceptTimestamp >= 10) {
        NSLog(@"accept timeout");
        [self.acceptTimer invalidate];
        
        //onaccepttimeout
        [self onAcceptTimeout];
    }
}

-(void)sendDialRefuse {
    [self sendControlCommand:VOIP_COMMAND_REFUSE];
}

-(void)sendHangUp {
    NSLog(@"send hang up");
    [self sendControlCommand:VOIP_COMMAND_HANG_UP];
}


-(void)processVOIPMessage:(NSDictionary*)obj sender:(int64_t)sender {
    if (sender != self.peerUID) {
        [self sendTalking:sender];
        return;
    }
    
    VOIPCommand *command = [[VOIPCommand alloc] initWithContent:obj];
    NSLog(@"voip state:%d command:%d", self.state, command.cmd);
    if (self.state == VOIP_DIALING) {
        if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
            self.state = VOIP_CONNECTED;
            [self.dialTimer invalidate];
            self.dialTimer = nil;
            
            //onconnected
            [self onConnected];
            [self ping];
        } else if (command.cmd == VOIP_COMMAND_REFUSE) {
            self.state = VOIP_REFUSED;
            
            [self sendRefused];
            
            [self.dialTimer invalidate];
            self.dialTimer = nil;
            
            //onrefuse
            [self onRefuse];
            
        } else if (command.cmd == VOIP_COMMAND_TALKING) {
            self.state = VOIP_SHUTDOWN;
            
            [self.dialTimer invalidate];
            self.dialTimer = nil;
            
            [self onTalking];
        }
    } else if (self.state == VOIP_ACCEPTING) {
        if (command.cmd == VOIP_COMMAND_HANG_UP) {
            self.state = VOIP_HANGED_UP;
            //onhangup
            [self onHangUp];
        }
    } else if (self.state == VOIP_ACCEPTED) {
        if (command.cmd == VOIP_COMMAND_CONNECTED) {
            NSLog(@"called voip connected");
            [self.acceptTimer invalidate];
            self.state = VOIP_CONNECTED;
            
            //onconnected
            [self onConnected];
            [self ping];
        }
    } else if (self.state == VOIP_CONNECTED) {
        if (command.cmd == VOIP_COMMAND_HANG_UP) {
            self.state = VOIP_HANGED_UP;
            
            //onhangup
            [self onHangUp];
        } else if (command.cmd == VOIP_COMMAND_ACCEPT) {
            [self sendConnected];
        } else if (command.cmd == VOIP_COMMAND_PING) {
            self.lastPingTimestamp = time(NULL);
        }
    }
}


-(void)dialVoice {
    self.state = VOIP_DIALING;
    self.mode = SESSION_VOICE;
    
    self.dialBeginTimestamp = time(NULL);
    [self sendDial];
    self.dialTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                      target:self
                                                    selector:@selector(sendDial)
                                                    userInfo:nil
                                                     repeats:YES];
}

-(void)dialVideo {
    self.state = VOIP_DIALING;
    self.mode = SESSION_VIDEO;
    
    self.dialBeginTimestamp = time(NULL);
    [self sendDial];
    self.dialTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                      target:self
                                                    selector:@selector(sendDial)
                                                    userInfo:nil
                                                     repeats:YES];
}

-(void)accept {
    self.state = VOIP_ACCEPTED;
    self.acceptTimestamp = time(NULL);
    self.acceptTimer = [NSTimer scheduledTimerWithTimeInterval: 1
                                                        target:self
                                                      selector:@selector(sendDialAccept)
                                                      userInfo:nil
                                                       repeats:YES];
    [self sendDialAccept];
}

-(void)refuse {
    self.state = VOIP_REFUSED;
    [self sendDialRefuse];
}

-(void)hangUp {
    if (self.state == VOIP_DIALING ) {
        [self.dialTimer invalidate];
        self.dialTimer = nil;
        
        [self sendHangUp];
        self.state = VOIP_HANGED_UP;
    } else if (self.state == VOIP_CONNECTED) {
        [self sendHangUp];
        self.state = VOIP_HANGED_UP;
    }else {
        NSLog(@"invalid voip state:%d", self.state);
    }
}

-(void)sendPing {
    [self sendControlCommand:VOIP_COMMAND_PING];
    
    time_t now = time(NULL);
    
    if (now - self.lastPingTimestamp > 10) {
        [self onDisconnect];
    }
}

-(void)ping {
    self.lastPingTimestamp = time(NULL);
    self.pingTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                      target:self
                                                    selector:@selector(sendPing)
                                                    userInfo:nil
                                                     repeats:YES];
    [self sendPing];
}

@end
