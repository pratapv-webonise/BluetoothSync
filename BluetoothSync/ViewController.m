//
//  ViewController.m
//  BluetoothSync
//
//  Created by Mac-4 on 07/10/14.
//  Copyright (c) 2014 WeboniseLab. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()
            

@end

@implementation ViewController
            
- (void)viewDidLoad {
    [super viewDidLoad];
    
    //central is Looking for periferal
    dispatch_queue_t centralQueue = dispatch_queue_create("mycentralqueue", DISPATCH_QUEUE_SERIAL);
    _centralManager = [[CBCentralManager alloc]initWithDelegate:self queue:centralQueue];
    _data = [[NSMutableData alloc]init];
    isPlaying = false;
    
    _groupPlaySwitch.on = false;
    _groupPlaySwitch.hidden = YES;
    _publishVideoSwitch.on = false;
    saveOldFinalSeekTime = 0.0;
    
    isGroupVideo = NO;
    isBufferStatus = NO;
    
    _detectedDevices = [[NSMutableArray alloc]init];
    oldGroupStatus = @"";
//    [self GroupPlayValidity:@"NO"];
       [self setframeoperation];
}

-(void)GroupPlayValidity:(NSString *)isGroupPlayString
{
    NSLog(@"IN SCREEN CHANGES");
    
    if([isGroupPlayString isEqualToString:@"NO"])
    {
        //Normal Screen
        
        NSLog(@"zoom out");
        
        x = 0;
        y = 117;
        width = 320;
        
        scaleX = 1;
    
    }
    else
    {
        if (isPublishVideo == YES)
        {
            NSLog(@"This is periferal");
            //This is periferal
            x = 0;
            y = 117;
            width = 640;
            scaleX = 2;
            
            
        }
        else
        {
            //This is central
            
            NSLog(@"This is right half");
            x = -360;
            y = 117;
            width = 640;
            scaleX = 2;
            
        }
    }
    
//    [self webviewFramesChange];
   [self performSelectorOnMainThread:@selector(webviewFramesChange) withObject:nil waitUntilDone:NO];
}

-(void)webviewFramesChange
{
    [self.webView setFrame:CGRectMake(x, y, 640, 451)];
    self.webView.scrollView.scrollsToTop = YES;
    NSLog(@"%@",self.webView);
}


-(IBAction)publishVideoSwitchChanged:(id)sender
{
    
    if(_publishVideoSwitch.isOn){
    _groupPlaySwitch.hidden = NO;
        isPublishVideo = YES;
    }
    else{
        _groupPlaySwitch.hidden = YES;
        isPublishVideo = NO;
    }
    
    NSLog(@"Peripheral device....");
    //Advertise periferal
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:nil];
    [_peripheralManager startAdvertising:@{ CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] }];

}


-(IBAction)groupPlaySwitchChanged:(id)sender
{
    if(_groupPlaySwitch.isOn == YES)
    {
        
        isGroupVideo = YES;
        
        if(isPublishVideo == YES)
        {
            [self.webView setFrame:CGRectMake(0, 117, 640, 451)];
        }
        else
        {
            [self.webView setFrame:CGRectMake(-360, 117, 640, 451)];
        }
    }
    else
    {
        isGroupVideo = NO;
        
        [self.webView setFrame:CGRectMake(0, 117, 320, 451)];
    }
}

/**********CENTRAL DELEGATE METHODS***********/

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"*************** CENTRAL STATUS ************");
    
    if(central.state!=CBCentralManagerStatePoweredOn)
    {
        NSLog(@"Bluetooth service is off...");
        return;
    }
    
    if(central.state ==CBCentralManagerStatePoweredOn)
    {
        NSLog(@"Bluetooth service is working...");
        NSLog(@"Scanning for devices.....");
        
        [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
    }
}

-(void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI{
   
    
    if(_discoveredPeripheral !=peripheral){
        _discoveredPeripheral = peripheral;
        NSLog(@"CONNECTING TO THE PERIFERAL DEVICE....%@",peripheral.name);
        [_centralManager connectPeripheral:peripheral options:nil];
    }
    
    NSUInteger index = [_detectedDevices indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop)
                        {
                            CBPeripheral *p = obj;
                            if ([p.identifier isEqual:peripheral.identifier])
                            {
                                *stop = YES;
                                return YES;
                            }
                            return NO;
                        }];
    
    if (index == NSNotFound){
        index = _detectedDevices.count;
        [_detectedDevices addObject:peripheral];
    }
    else{
        [_detectedDevices replaceObjectAtIndex:index withObject:peripheral];
    }
    
    peripheral.delegate = self;
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    NSLog(@"Failed to connect");
    [self cleanup];
}

- (void)cleanup {
    if (_discoveredPeripheral.services != nil) {
        for (CBService *service in _discoveredPeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
                        if (characteristic.isNotifying) {
                            [_discoveredPeripheral setNotifyValue:NO forCharacteristic:characteristic];
                            return;
                        }
                    }
                }
            }
        }
    }
    
    [_centralManager cancelPeripheralConnection:_discoveredPeripheral];
}


-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Connected....");
    [_centralManager stopScan];
    NSLog(@"Scanning stopped...");
    [_data setLength:0];
    peripheral.delegate = self;
    [peripheral discoverServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]]];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    
    NSLog(@"SERVICES DISCOVERED.....");
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBService *service in peripheral.services) {
        [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]] forService:service];
    }
}


- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    NSLog(@"Char DICOVERED");
    
    if (error) {
        [self cleanup];
        return;
    }
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
            if(isPlaying == false)
            {
                [self performSelectorOnMainThread:@selector(prepareVideo) withObject:nil waitUntilDone:NO];
                isPlaying = true;
            }
        }
    }
    
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)
error {
    
    if (error) {
        NSLog(@"Error");
        return;
    }
    
    NSString *stringFromData = [[NSString alloc] initWithData:characteristic.value encoding:NSUTF8StringEncoding];
    NSArray *arr = [stringFromData componentsSeparatedByString:@"+"];
    double playtime = [arr[1] floatValue];
    
    timedelay = 0;
    finalTime =  playtime + 0.4;
    if(![oldGroupStatus isEqualToString:arr[2]]){
        NSLog(@"Fullscreen: %@",arr[2]);
        screenSize = arr[2];
        [self performSelectorOnMainThread:@selector(setframeoperation) withObject:nil waitUntilDone:YES];
        oldGroupStatus = arr[2];
    }
    [self performSelectorOnMainThread:@selector(youtubeoperation) withObject:nil waitUntilDone:NO];
}


-(void)setframeoperation{
    if([screenSize isEqualToString:@"YES"]){
        NSLog(@"640 width");
         isGroupVideo = YES;
        if (isPublishVideo) {
            [_webView setFrame:CGRectMake(0, 117, 640, 451)];
        }
        else{
            [_webView setFrame:CGRectMake(-360, 117, 640, 451)];
        }
    }
    else
    {
        NSLog(@"320 width");
         isGroupVideo = NO;
        [_webView setFrame:CGRectMake(0, 117, 320, 451)];
    }
    NSLog(@"%@",_webView);
}

-(void)youtubeoperation{

    [self.webView stringByEvaluatingJavaScriptFromString:
    [NSString stringWithFormat:@"ytplayer.seekTo(%f,true)",finalTime]];
    [self getPlayerState];
    
//    NSNumberFormatter *fmt = [[NSNumberFormatter alloc] init];
//    [fmt setNumberStyle:NSNumberFormatterDecimalStyle];
//    [fmt setMaximumFractionDigits:1];
//
//    if (saveOldFinalSeekTime != finalTime) {
//                saveOldFinalSeekTime = finalTime;
//        [self.webView stringByEvaluatingJavaScriptFromString:
//         [NSString stringWithFormat:@"ytplayer.seekTo(%f)",finalTime]];
//        [self setVolume:volume];
//    }

    //update buffered Data
    _bufferedDataLabel.text = [NSString stringWithFormat:@"%f",[self getBufferedDataPercent]*100 ];
}

-(void)prepareVideo{
//    NSLog(@"MAin method calling...");
    
    [self.webView setAllowsInlineMediaPlayback:YES];
    [self.webView setMediaPlaybackRequiresUserAction:NO];
    [self.view addSubview:self.webView];
    self.webView.delegate = self;
    
    NSString* embedHTML = [NSString stringWithFormat:@"\
                           <html>\
                           <body style='margin:0px;padding:0px;'>\
                           <script type='text/javascript' src='http://www.youtube.com/iframe_api'></script>\
                           <script type='text/javascript'>\
                           function onYouTubeIframeAPIReady()\
                           {\
                           ytplayer=new YT.Player('playerId',{events:{onReady:onPlayerReady}})\
                           }\
                           function onPlayerReady(a)\
                           { \
                           a.target.playVideo(); \
                           }\
                           </script>\
                           <iframe id='playerId' type='text/html'  width=\"100%%\" height=\"100%%\" src='http://www.youtube.com/embed/%@?enablejsapi=1&rel=0&playsinline=1&autoplay=1' frameborder='0'>\
                           </body>\
                           </html>", @"w9j3-ghRjBs"];
    
    [self.webView loadHTMLString:embedHTML baseURL:[[NSBundle mainBundle] resourceURL]];

    if(isPublishVideo == YES){
        [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(getCurrentStatusVideo) userInfo:nil repeats:YES];
    }
    [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(DisplyCurrentTime) userInfo:nil repeats:YES];
}

-(double)caluculateDelay:(NSString *)recivedTimeStamp{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
    
    double finalInterval = [[NSDate date] timeIntervalSince1970] - [recivedTimeStamp doubleValue];
    
    if (finalInterval<0) {
        finalInterval = finalInterval *-1;
    }
    return finalInterval;
}


- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID]]) {
        return;
    }
    
    if (characteristic.isNotifying){
    } else{
        [_centralManager cancelPeripheralConnection:peripheral];
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    _discoveredPeripheral = nil;
    [_centralManager scanForPeripheralsWithServices:@[[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID]] options:@{ CBCentralManagerScanOptionAllowDuplicatesKey : @YES }];
}


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [_centralManager stopScan];
}




/*****************PERIFERAL METHODS*****************************/

-(void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    if (peripheral.state != CBPeripheralManagerStatePoweredOn) {
        return;
    }
    
    if (peripheral.state == CBPeripheralManagerStatePoweredOn) {
        self.transferCharacteristic = [[CBMutableCharacteristic alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_CHARACTERISTIC_UUID] properties:CBCharacteristicPropertyNotify value:nil permissions:CBAttributePermissionsReadable];
        CBMutableService *transferService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:TRANSFER_SERVICE_UUID] primary:YES];
        transferService.characteristics = @[_transferCharacteristic];
        [_peripheralManager addService:transferService];
    }
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic {
    [self performSelectorOnMainThread:@selector(prepareVideo) withObject:nil waitUntilDone:NO];
}



-(void)DisplyCurrentTime{
    NSString *body = [self.webView stringByEvaluatingJavaScriptFromString:
                      @"ytplayer.getCurrentTime()"];
    _currentPlayTimeLabel.text = body;
}

-(void)getCurrentStatusVideo{
    NSString *body = [self.webView stringByEvaluatingJavaScriptFromString:
                      @"ytplayer.getCurrentTime()"];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
      [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
    NSString * timestamp = [dateFormatter stringFromDate:[NSDate date]];
    
    timestamp =[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    
    NSString * isGroupPlayString;
    if(isGroupVideo == YES)
        isGroupPlayString = @"YES";
    else
        isGroupPlayString = @"NO";

    NSString *combineString = [NSString stringWithFormat:@"%@+%@+%@+%@",timestamp,body,isGroupPlayString,[self getPlayerVolume]];
    NSData* data = [combineString dataUsingEncoding:NSUTF8StringEncoding];
    [self.peripheralManager updateValue:data forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
    _bufferedDataLabel.text = [NSString stringWithFormat:@"%f",[self getBufferedDataPercent]*100 ];
}

- (void)webViewDidStartLoad:(UIWebView *)webView{
    if(isPublishVideo == YES){
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc]init];
    dateFormatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss.SSS";
      [dateFormatter setTimeZone:[NSTimeZone systemTimeZone]];
    
     NSString * timestamp = [dateFormatter stringFromDate:[NSDate date]];
    timestamp =[NSString stringWithFormat:@"%f",[[NSDate date] timeIntervalSince1970]];
    
    NSString * isGroupPlayString;
    if(isGroupVideo == YES)
     isGroupPlayString = @"YES";
    else
     isGroupPlayString = @"NO";
    
    NSString *combineString = [NSString stringWithFormat:@"%@+0.00+%@+100",timestamp,isGroupPlayString];
    NSData* data = [combineString dataUsingEncoding:NSUTF8StringEncoding];
    [self.peripheralManager updateValue:data forCharacteristic:self.transferCharacteristic onSubscribedCentrals:nil];
    }
}
- (void)webViewDidFinishLoad:(UIWebView *)webView{
//    if(isPublishVideo)
//        [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(checkBufferStatus) userInfo:nil repeats:NO];
//    else
//        [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(checkBufferStatus) userInfo:nil repeats:NO];
//    
//    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(holdtheVideo) userInfo:nil repeats:YES];
}

-(void)holdtheVideo{
    if(isBufferStatus == YES){
//        NSLog(@"now play");
    }
    else{
        NSLog(@"Stop");
    [self.webView stringByEvaluatingJavaScriptFromString:
     @"ytplayer.seekTo(0,true)"];
    }
}

-(void)checkBufferStatus{
    isBufferStatus = YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error{
}

-(void)moviePlayBackDidFinish:(NSDictionary *)dict{
}

-(void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral {
}

-(NSString *)getPlayerVolume{
    volume =  [self.webView stringByEvaluatingJavaScriptFromString:
                      @"ytplayer.getVolume()"];
    return volume;
}

-(void)setVolume:(NSString *)vol{
    volume =  [self.webView stringByEvaluatingJavaScriptFromString:[NSString stringWithFormat:@"ytplayer.setVolume(%d)",[vol integerValue]]];
}

-(void)playVideo{
    NSLog(@"play Video...");
    [self.webView stringByEvaluatingJavaScriptFromString:
     @"ytplayer.playVideo()"];
}

-(void)pauseVideo{
    NSLog(@"Pause Video...");
    [self.webView stringByEvaluatingJavaScriptFromString:
     @"ytplayer.pauseVideo()"];
}

-(float)getBufferedDataPercent{
  float buffredData =  [[self.webView stringByEvaluatingJavaScriptFromString:
     @"ytplayer.getVideoLoadedFraction()"] floatValue];
    return buffredData;
}

-(float)getPlayerState{
    float State =  [[self.webView stringByEvaluatingJavaScriptFromString:
                           @"ytplayer.getPlayerState()"] floatValue];
    youtubeState = State;
    self.playerStatusLabel.text = [NSString stringWithFormat:@"%f",State];
    return State;
}

/***************************************************************/

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}
@end
