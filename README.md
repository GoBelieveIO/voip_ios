#voip ios sdk

##运行demo
    输入双方的uid， 一方呼叫， 一方接听


##信令通话的初始化参考[im](https://github.com/GoBelieveIO/im_ios)工程

##发起视频呼叫

        VOIPVideoViewController *controller = [[VOIPVideoViewController alloc] init];
        controller.currentUID = uid;
        controller.peerUID = peerUID;
        controller.peerName = @"";
        controller.token = token;
        controller.isCaller = YES;
        controller.channelID = channelID;

        [self presentViewController:controller animated:YES completion:nil];

##发起语音呼叫


        VOIPVoiceViewController *controller = [[VOIPVoiceViewController alloc] init];
        controller.currentUID = uid;
        controller.peerUID = peerUID;
        controller.peerName = @"";
        controller.token = token;
        controller.isCaller = YES;
        controller.channelID = channelID;

        [self presentViewController:controller animated:YES completion:nil];