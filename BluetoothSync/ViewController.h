//
//  ViewController.h
//  BluetoothSync
//
//  Created by Mac-4 on 07/10/14.
//  Copyright (c) 2014 WeboniseLab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SERVICES.h"
#import <CoreBluetooth/CoreBluetooth.h>

typedef enum YoutubePlayerStatus:NSInteger PlayerStateType;
enum PlayerStateType : NSInteger
{
    UNSTARTED,
    ENDED,
    PLAYING,
    PAUSED,
    BUFFERING,
    VIDEO_CUED
};

@interface ViewController : UIViewController<CBCentralManagerDelegate,CBPeripheralDelegate,CBPeripheralManagerDelegate,UIWebViewDelegate>
{
    BOOL isCentralDevice;
    
    //central
    BOOL isPlaying;
    double timedelay;
    double finalTime;
    BOOL isGroupVideo;
    BOOL isPublishVideo;
    NSString *oldGroupStatus;
    int x,y,width,scaleX,scaleY;
    NSString *volume;
    double saveOldFinalSeekTime;
    
    PlayerStateType youtubeState;
    
    NSString *screenSize;
    BOOL isBufferStatus;
    
}
//UI
@property(nonatomic,strong)IBOutlet UISwitch *publishVideoSwitch;
@property(nonatomic,strong)IBOutlet UISwitch *groupPlaySwitch;
@property(nonatomic,strong)IBOutlet UILabel *deviceNameLabel;
@property(nonatomic,strong)IBOutlet UIWebView *webView;
@property(nonatomic,strong)IBOutlet UILabel *bufferedDataLabel;
@property(nonatomic,strong)IBOutlet UILabel *currentPlayTimeLabel;
@property(nonatomic,strong)IBOutlet UILabel *playerStatusLabel;

//central
@property (strong,nonatomic) CBCentralManager *centralManager;
@property (nonatomic,strong) CBPeripheral *discoveredPeripheral;
@property (strong,nonatomic) NSMutableData *data;
@property (strong,nonatomic) NSMutableArray *detectedDevices;

//periferal
@property (strong,nonatomic) CBPeripheralManager *peripheralManager;
@property (strong,nonatomic) CBMutableCharacteristic *transferCharacteristic;
@property (strong,nonatomic) NSData *dataToSend;
@property (nonatomic,readwrite) NSInteger sendDataIndex;


-(IBAction)publishVideoSwitchChanged:(id)sender;
-(IBAction)groupPlaySwitchChanged:(id)sender;

@end

