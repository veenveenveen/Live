//
//  ViewController.m
//  Webcast
//
//  Created by 黄启明 on 2017/4/13.
//  Copyright © 2017年 黄启明. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property(strong, nonatomic) AVCaptureSession *captureSession;
@property(strong, nonatomic) AVCaptureDeviceInput *videoDeviceInput;
@property(strong, nonatomic) AVCaptureConnection *captureConnection;
@property(strong, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@property(weak, nonatomic) UIImageView *focusImageView;

@property(assign, nonatomic) BOOL isFocusing;

@end

@implementation ViewController

//懒加载聚焦视图
- (UIImageView *)focusImageView {
    if (_focusImageView == nil) {
        UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"focus"]];
        _focusImageView = imageView;
        [self.view addSubview:_focusImageView];
    }
    return _focusImageView;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    _isFocusing = false;//刚开始未执行聚焦动画
    
    [self setCaptureVideo];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//采集音视频
- (void)setCaptureVideo {
    //创建捕捉会话
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    _captureSession = session;
    
    //获取摄像头设备，默认后置摄像头
    AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:AVCaptureDevicePositionBack];
    //获取声音设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    
    //创建视频设备输入对象
    AVCaptureDeviceInput *videoInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:nil];
    _videoDeviceInput = videoInput;
    
    //创建音频设备输入对象
    AVCaptureDeviceInput *audioInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    
    //添加到会话中
    if ([session canAddInput:videoInput]) {
        [session addInput:videoInput];
    }
    if ([session canAddInput:audioInput]) {
        [session addInput:audioInput];
    }
    
    //获取视频数据输出设备
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    //设置代理 捕获视频样品数据
    //队列必须是串行队列，才能获取到数据，而且不能为空
    dispatch_queue_t videoQueue = dispatch_queue_create("Video Capture Queue", DISPATCH_QUEUE_SERIAL);
    [videoOutput setSampleBufferDelegate:self queue:videoQueue];
    if ([session canAddOutput:videoOutput]) {
        [session addOutput:videoOutput];
    }
    
    //获取音频数据输出设备
    AVCaptureAudioDataOutput *audioOutput = [[AVCaptureAudioDataOutput alloc] init];
    //设置代理 捕捉音频样品数据
    dispatch_queue_t audioQueue = dispatch_queue_create("Audio Capture Queue", DISPATCH_QUEUE_SERIAL);
    [audioOutput setSampleBufferDelegate:self queue:audioQueue];
    if ([session canAddOutput:audioOutput]) {
        [session addOutput:audioOutput];
    }
    
    //获取视频输入与输出连接，用于分辨音视频数据
    _captureConnection = [videoOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //添加视频预览图层
    AVCaptureVideoPreviewLayer *layer = [AVCaptureVideoPreviewLayer layerWithSession:session];
    layer.frame = [UIScreen mainScreen].bounds;
    [self.view.layer insertSublayer:layer atIndex:0];
    _previewLayer = layer;
    
    //启动会话
    [session startRunning];
}

//切换摄像头
- (IBAction)switchCamera:(id)sender {
    //获取当前摄像头的位置
    AVCaptureDevicePosition curPosition = _videoDeviceInput.device.position;
    //获取需要改变的方向
    AVCaptureDevicePosition switchPosition = curPosition == AVCaptureDevicePositionFront ? AVCaptureDevicePositionBack : AVCaptureDevicePositionFront;
    //获取改变的摄像头设备
    AVCaptureDevice *switchDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:switchPosition];
    //获取改变的摄像头输入对象
    AVCaptureDeviceInput *switchDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:switchDevice error:nil];
    
    //移除当前的设备，添加新的设备
    [_captureSession removeInput:_videoDeviceInput];
    [_captureSession addInput:switchDeviceInput];
    
    _videoDeviceInput = switchDeviceInput;
}

//点击屏幕，出现聚焦视图
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    //获取点击位置
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self.view];
    
    //把当前位置转换为当前摄像头点上的位置
    CGPoint cameraPoint = [_previewLayer captureDevicePointOfInterestForPoint:point];
    
    //设置聚点光标位置 聚焦
    [self setFocusCursorPositionWith:point andCameraPoint: cameraPoint];
    
}

//设置光标位置 聚焦
- (void)setFocusCursorPositionWith: (CGPoint)point andCameraPoint: (CGPoint)cameraPoint {
    if (!self.isFocusing) {
        self.isFocusing = true;
        
        //设置聚焦
        [self focusWithMode:AVCaptureFocusModeAutoFocus exposureMode:AVCaptureExposureModeAutoExpose atPoint:cameraPoint];
        
        self.focusImageView.center = point;
        self.focusImageView.transform = CGAffineTransformMakeScale(1.5, 1.5);
        self.focusImageView.alpha = 1.0;
        [UIView animateWithDuration:1 animations:^{
            self.focusImageView.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            self.focusImageView.alpha = 0;
            self.isFocusing = false;
        }];
    }
}

//设置聚焦
- (void)focusWithMode: (AVCaptureFocusMode)captureFocusMode exposureMode: (AVCaptureExposureMode)captureExposureMode atPoint: (CGPoint)point {
    AVCaptureDevice *captureDevice = _videoDeviceInput.device;
    //锁定配置
    [captureDevice lockForConfiguration:nil];
    
    //设置聚焦
    if ([captureDevice isFocusModeSupported:captureFocusMode]) {
        [captureDevice setFocusMode:captureFocusMode];
    }
    if ([captureDevice isFocusPointOfInterestSupported]) {
        [captureDevice setFocusPointOfInterest:point];
    }
    
    //设置曝光
    if ([captureDevice isExposureModeSupported:captureExposureMode]) {
        [captureDevice setExposureMode:captureExposureMode];
    }
    if ([captureDevice isExposurePointOfInterestSupported]) {
        [captureDevice setExposurePointOfInterest:point];
    }
    
    //解锁配置
    [captureDevice unlockForConfiguration];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

// 获取输入设备数据，有可能是音频有可能是视频
- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (_captureConnection == connection) {
        NSLog(@"采集到视频数据");
    }
    else {
        NSLog(@"采集到音频数据");
    }
}

@end
