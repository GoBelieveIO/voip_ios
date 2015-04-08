//
//  ViewController.m
//  demo
//
//  Created by houxh on 15/3/30.
//  Copyright (c) 2015年 beetle. All rights reserved.
//

#import "ViewController.h"
#import "MBProgressHUD.h"
#import <voipsession/VOIPSession.h>
#import <voipengine/VOIPEngine.h>
#import <voipsession/VOIPService.h>
#import "VOIPViewController.h"

@interface ViewController ()<VOIPObserver>
@property (weak, nonatomic) IBOutlet UITextField *myTextField;

@property (weak, nonatomic) IBOutlet UITextField *peerTextField;

@property(nonatomic) MBProgressHUD *hud;
@property(nonatomic) int64_t myUID;
@property(nonatomic) int64_t peerUID;
@property(nonatomic, copy) NSString *token;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];


    //app可以单独部署服务器，给予第三方应用更多的灵活性
    //在开发阶段也可以配置成测试环境的地址 "sandbox.voipnode.gobelieve.io"
    [VOIPService instance].host = @"voipnode.gobelieve.io";
    [VOIPService instance].deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [[VOIPService instance] startRechabilityNotifier];
}

- (IBAction)dial:(id)sender {
    [self.myTextField resignFirstResponder];
    [self.peerTextField resignFirstResponder];
    
    int64_t myUID = [self.myTextField.text longLongValue];
    int64_t peerUID = [self.peerTextField.text longLongValue];
    
    if (myUID == 0 || peerUID == 0) {
        return;
    }
    
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
    self.hud.labelText = @"登录中...";
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *token = [self login:myUID];
        NSLog(@"token:%@", token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [VOIPService instance].token = token;
            [[VOIPService instance] start];
            self.token = token;
            [self.hud hide:NO];
            
            VOIPViewController *controller = [[VOIPViewController alloc] init];
            controller.currentUID = self.myUID;
            controller.peerUID = self.peerUID;
            controller.peerName = @"测试";
            controller.token = self.token;
            controller.isCaller = YES;
            
            [self presentViewController:controller animated:YES completion:nil];
            
            
        });
    });
        

}
- (IBAction)receiveCall:(id)sender {
    [self.myTextField resignFirstResponder];
    [self.peerTextField resignFirstResponder];
    
    int64_t myUID = [self.myTextField.text longLongValue];
    int64_t peerUID = [self.peerTextField.text longLongValue];
    
    if (myUID == 0 || peerUID == 0) {
        return;
    }

    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
    self.hud.labelText = @"登录中...";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *token = [self login:myUID];
        NSLog(@"token:%@", token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [VOIPService instance].token = token;
            [[VOIPService instance] start];
            self.token = token;
            
            self.hud.labelText = @"等待中...";
            //等待呼叫
            [[VOIPService instance] pushVOIPObserver:self];
            
            self.myUID = myUID;
            self.peerUID = peerUID;

        });
    });
    
}

-(void)onVOIPControl:(VOIPControl*)ctl {
    if (ctl.cmd == VOIP_COMMAND_DIAL) {
        if (ctl.sender == self.peerUID) {
            
            [self.hud hide:NO];
            
            
            VOIPViewController *controller = [[VOIPViewController alloc] init];
            controller.currentUID = self.myUID;
            controller.peerUID = self.peerUID;
            controller.peerName = @"测试";
            controller.token = self.token;
            controller.isCaller = NO;
            
            [self presentViewController:controller animated:YES completion:nil];
        }
    }
}

-(NSString*)login:(long long)uid {
    //调用app自身的登陆接口获取voip服务必须的access token
    //sandbox地址："http://sandbox.demo.gobelieve.io/auth/token"
    NSString *url = @"http://demo.gobelieve.io/auth/token";
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:60];
    
    
    [urlRequest setHTTPMethod:@"POST"];
    
    NSDictionary *headers = [NSDictionary dictionaryWithObject:@"application/json" forKey:@"Content-Type"];
    
    [urlRequest setAllHTTPHeaderFields:headers];
    
    
    NSDictionary *obj = [NSDictionary dictionaryWithObject:[NSNumber numberWithLongLong:uid] forKey:@"uid"];
    NSData *postBody = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
    
    [urlRequest setHTTPBody:postBody];
    
    NSURLResponse *response = nil;
    
    NSError *error = nil;
    
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest returningResponse:&response error:&error];
    if (error != nil) {
        NSLog(@"error:%@", error);
        return nil;
    }
    NSHTTPURLResponse *httpResp = (NSHTTPURLResponse*)response;
    if (httpResp.statusCode != 200) {
        return nil;
    }
    NSDictionary *e = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:nil];
    return [e objectForKey:@"token"];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
