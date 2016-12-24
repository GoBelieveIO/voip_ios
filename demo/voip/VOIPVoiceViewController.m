//
//  VOIPVoiceViewController.m
//  voip_demo
//
//  Created by houxh on 15/9/7.
//  Copyright (c) 2015年 beetle. All rights reserved.
//
#import "VOIPVoiceViewController.h"
#import <WebRTC/WebRTC.h>
#import "ARDSDPUtils.h"
#import "ReflectionView.h"
#import "UIView+Toast.h"

#define kBtnWidth  72
#define kBtnHeight 72

#define kBtnSqureWidth  200
#define kBtnSqureHeight 50

#define KheaderViewWH  100

#define kBtnYposition  (self.view.frame.size.height - 2.5*kBtnSqureHeight)

//RGB颜色
#define RGBCOLOR(r,g,b) [UIColor colorWithRed:(r)/255.0f green:(g)/255.0f blue:(b)/255.0f alpha:1]


@interface VOIPVoiceViewController ()
@property(nonatomic) UIButton *hangUpButton;
@property(nonatomic) UIButton *acceptButton;
@property(nonatomic) UIButton *refuseButton;

@property(nonatomic) UILabel *durationLabel;
@property(nonatomic) ReflectionView *headView;

@property(nonatomic) NSTimer *refreshTimer;

@property(nonatomic) int duration;
@end

@implementation VOIPVoiceViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.isAudioOnly = YES;
    self.duration = 0;
    
    // Do any additional setup after loading the view, typically from a nib.
    [self.view setBackgroundColor:[UIColor whiteColor]];
    
    UIImageView *imgView = [[UIImageView alloc]
                            initWithFrame:CGRectMake(0,0, KheaderViewWH,
                                                     KheaderViewWH)];
    
    imgView.image = [UIImage imageNamed:@"PersonalChat"];
    
    CALayer *imageLayer = [imgView layer];  //获取ImageView的层
    [imageLayer setMasksToBounds:YES];
    [imageLayer setCornerRadius:imgView.frame.size.width / 2];
    
    self.headView = [[ReflectionView alloc] initWithFrame:CGRectMake((self.view.frame.size.width-KheaderViewWH)/2,80, KheaderViewWH,KheaderViewWH)];
    self.headView.alpha = 0.9f;
    self.headView.reflectionScale = 0.3f;
    self.headView.reflectionGap = 1.0f;
    [self.headView addSubview:imgView];
    
    [self.view addSubview:self.headView];
    
    
    self.durationLabel = [[UILabel alloc] init];
    [self.durationLabel setFont:[UIFont systemFontOfSize:23.0f]];
    [self.durationLabel setTextAlignment:NSTextAlignmentCenter];
    [self.durationLabel sizeToFit];
    [self.durationLabel setTextColor: RGBCOLOR(11, 178, 39)];
    [self.durationLabel setHidden:YES];
    [self.view addSubview:self.durationLabel];
    [self.durationLabel setCenter:CGPointMake((self.view.frame.size.width)/2, self.headView.frame.origin.y + self.headView.frame.size.height + 50)];
    [self.durationLabel setBackgroundColor:[UIColor clearColor]];
    
    self.acceptButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.acceptButton.frame = CGRectMake(30.0f, self.view.frame.size.height - kBtnHeight - kBtnHeight, kBtnWidth, kBtnHeight);
    [self.acceptButton setCenter:CGPointMake(self.view.frame.size.width/4 + self.view.frame.size.width/2, kBtnYposition)];
    [self.acceptButton setBackgroundImage: [UIImage imageNamed:@"Call_Ans"] forState:UIControlStateNormal];
    
    [self.acceptButton setBackgroundImage:[UIImage imageNamed:@"Call_Ans_p"] forState:UIControlStateHighlighted];
    [self.acceptButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.acceptButton addTarget:self
                          action:@selector(acceptCall:)
                forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:self.acceptButton];
    
    self.refuseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.refuseButton.frame = CGRectMake(0,0, kBtnWidth, kBtnHeight);
    [self.refuseButton setCenter:CGPointMake(self.view.frame.size.width/4, kBtnYposition)];
    [self.refuseButton setBackgroundImage:[UIImage imageNamed:@"Call_hangup"] forState:UIControlStateNormal];
    [self.refuseButton setBackgroundImage:[UIImage imageNamed:@"Call_hangup_p"] forState:UIControlStateHighlighted];
    [self.refuseButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.refuseButton addTarget:self
                          action:@selector(refuseCall:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.refuseButton];
    
    self.hangUpButton = [[UIButton alloc] initWithFrame:CGRectMake(0,0, kBtnSqureWidth, kBtnSqureHeight)];
    [self.hangUpButton setBackgroundImage:[UIImage imageNamed:@"refuse_nor"] forState:UIControlStateNormal];
    [self.hangUpButton setBackgroundImage:[UIImage imageNamed:@"refuse_pre"] forState:UIControlStateHighlighted];
    [self.hangUpButton setTitle:@"挂断" forState:UIControlStateNormal];
    [self.hangUpButton.titleLabel setFont:[UIFont systemFontOfSize:20.0f]];
    [self.hangUpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.hangUpButton addTarget:self
                          action:@selector(hangUp:)
                forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.hangUpButton];
    [self.hangUpButton setCenter:CGPointMake(self.view.frame.size.width / 2, kBtnYposition)];
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    if (self.isCaller) {
        self.acceptButton.hidden = YES;
        self.refuseButton.hidden = YES;
    } else {
        self.hangUpButton.hidden = YES;
    }
    
    if (self.isCaller) {
        if (self.channelID.length == 0){
            //todo 异步从服务器接口获取
            self.channelID = [[NSUUID UUID] UUIDString];
        }
        [self dialVoice];
    }
    
    [self requestPermission];
}

- (void)requestPermission {
    AVAuthorizationStatus audioAuthStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if(audioAuthStatus == AVAuthorizationStatusAuthorized) {
        
    } else if(audioAuthStatus == AVAuthorizationStatusDenied){
    } else if(audioAuthStatus == AVAuthorizationStatusRestricted){
    } else if(audioAuthStatus == AVAuthorizationStatusNotDetermined){
        [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            if (granted) {
                NSLog(@"grant record permission");
            } else {
                NSLog(@"can't grant record permission");
            }
        }];
    }
}


- (NSString*)getTimeStrFromSeconds:(UInt64)seconds {
    if (seconds >= 3600) {
        return [NSString stringWithFormat:@"%02lld:%02lld:%02lld",seconds/3600,(seconds%3600)/60,seconds%60];
    }else{
        return [NSString stringWithFormat:@"%02lld:%02lld",(seconds%3600)/60,seconds%60];
    }
}


/**
 *  刷新时间显示
 */
-(void) refreshDuration{
    self.duration += 1;
    [self.durationLabel setText:[self getTimeStrFromSeconds:self.duration]];
    [self.durationLabel setCenter:CGPointMake((self.view.frame.size.width)/2, self.headView.frame.origin.y + self.headView.frame.size.height + 50)];
    [self.durationLabel sizeToFit];
}

-(void)refuseCall:(UIButton*)button {
    [self refuse];
    
    self.refuseButton.enabled = NO;
    self.acceptButton.enabled = NO;
    
    [self dismiss];
}

-(void)acceptCall:(UIButton*)button {
    [self accept];
    self.refuseButton.enabled = NO;
    self.acceptButton.enabled = NO;
}

-(void)hangUp:(UIButton*)button {
    [self hangUp];
    if (self.isConnected) {
        [self stopStream];
        [self dismiss];
    } else {
        [self dismiss];
    }
}

- (void)startStream {
    [self setLoudspeakerStatus:NO];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(refreshDuration) userInfo:nil repeats:YES];
    [self.refreshTimer fire];
    [super startStream];
}


- (void)stopStream {
    if (self.refreshTimer && [self.refreshTimer isValid]) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
    [super stopStream];
}

-(void)onConnected {
    [super onConnected];
    
    self.duration = 0;
    [self.durationLabel setHidden:NO];
    [self.durationLabel setText:[self getTimeStrFromSeconds:self.duration]];
    [self.durationLabel setCenter:CGPointMake((self.view.frame.size.width)/2, self.headView.frame.origin.y + self.headView.frame.size.height + 50)];
    [self.durationLabel sizeToFit];
    self.hangUpButton.hidden = NO;
    self.acceptButton.hidden = YES;
    self.refuseButton.hidden = YES;
}
@end
