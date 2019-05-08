//
//  ViewController.m
//  MDMImageDecoder
//
//  Created by mademao on 2019/3/22.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "ViewController.h"
#import <YYWebImage.h>

@interface ViewController ()

@property (nonatomic, strong) YYAnimatedImageView *imageView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.imageView = [[YYAnimatedImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)];
    self.imageView.center = self.view.center;
    self.imageView.backgroundColor = [UIColor whiteColor];
    self.imageView.layer.borderColor = [UIColor blackColor].CGColor;
    self.imageView.layer.borderWidth = 1.0f;
    [self.view addSubview:self.imageView];
    
    [self showDisposeBackgroundGIF];
//    [self showPNG];
}

- (void)showDisposeBackgroundGIF
{
    NSString *file = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"gif"];
    self.imageView.image = [YYImage imageWithContentsOfFile:[file stringByAppendingPathComponent:@"wolaile.gif"]];
//    self.imageView.image = [YYImage imageWithContentsOfFile:@"/Users/mademao/Desktop/test.gif"];
}

- (void)showPNG
{
    NSString *file = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"png"];
    self.imageView.image = [YYImage imageWithContentsOfFile:[file stringByAppendingPathComponent:@"dot.png"]];
}


@end
