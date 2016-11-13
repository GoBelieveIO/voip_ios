/*                                                                            
  Copyright (c) 2014-2015, GoBelieve     
    All rights reserved.		    				     			
 
  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree. An additional grant
  of patent rights can be found in the PATENTS file in the same directory.
*/

#import "ViewController.h"
#import "MBProgressHUD.h"
#import <voipsession/VOIPSession.h>
#import <voipsession/VOIPService.h>
#import "VOIPViewController.h"
#import "VOIPVideoViewController.h"
#import "VOIPVoiceViewController.h"

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
    //在开发阶段也可以配置成测试环境的地址 "sandbox.imnode.gobelieve.io", "sandbox.voipnode.gobelieve.io"
    [VOIPService instance].host = @"imnode2.gobelieve.io";
    [VOIPService instance].isSync = NO;
    [VOIPService instance].deviceID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    [[VOIPService instance] startRechabilityNotifier];
}

- (IBAction)dialVideo:(id)sender {
    [self.myTextField resignFirstResponder];
    [self.peerTextField resignFirstResponder];
    
    int64_t myUID = [self.myTextField.text longLongValue];
    int64_t peerUID = [self.peerTextField.text longLongValue];
    
    if (myUID == 0 || peerUID == 0) {
        return;
    }
    
    self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:NO];
    self.hud.labelText = @"登录中...";
    
    self.myUID = myUID;
    self.peerUID = peerUID;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *token = [self login:myUID];
        NSLog(@"token:%@", token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [VOIPService instance].token = token;
            [[VOIPService instance] start];
            self.token = token;
            [self.hud hide:NO];
            
            VOIPViewController *controller = [[VOIPVideoViewController alloc] init];
            controller.currentUID = self.myUID;
            controller.peerUID = self.peerUID;
            controller.peerName = @"测试";
            controller.token = self.token;
            controller.isCaller = YES;
            
            [self presentViewController:controller animated:YES completion:nil];
            
            
        });
    });
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
    
    self.myUID = myUID;
    self.peerUID = peerUID;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *token = [self login:myUID];
        NSLog(@"token:%@", token);
        dispatch_async(dispatch_get_main_queue(), ^{
            [VOIPService instance].token = token;
            [[VOIPService instance] start];
            self.token = token;
            [self.hud hide:NO];
            
            VOIPViewController *controller = [[VOIPVoiceViewController alloc] init];
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
    VOIPCommand *command = [[VOIPCommand alloc] initWithContent:ctl.content];
    if (command.cmd == VOIP_COMMAND_DIAL) {
        if (ctl.sender == self.peerUID) {
            
            [self.hud hide:NO];
            
            
            VOIPViewController *controller = [[VOIPVoiceViewController alloc] init];
            controller.currentUID = self.myUID;
            controller.peerUID = self.peerUID;
            controller.peerName = @"测试";
            controller.token = self.token;
            controller.isCaller = NO;
            
            [self presentViewController:controller animated:YES completion:nil];
        }
    } else if (command.cmd == VOIP_COMMAND_DIAL_VIDEO) {
        if (ctl.sender == self.peerUID) {
            
            [self.hud hide:NO];
            
            
            VOIPViewController *controller = [[VOIPVideoViewController alloc] init];
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
