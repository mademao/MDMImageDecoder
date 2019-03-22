//
//  MDMImage.m
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/20.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "MDMImage.h"
#import "MDMImageDecoder.h"
#import <objc/runtime.h>

#pragma mark - MDMImage(extension)

@interface MDMImage ()

@property (nonatomic, strong) MDMImageDecoder *imageDecoder;
@property (nonatomic, assign) BOOL handleBySelf;

- (instancetype)initWithImageDecoder:(id)imageDecoder scale:(CGFloat)scale;

@end


#pragma mark - YYImage (MDMImageHook)

@interface YYImage (MDMImageHook)

- (instancetype)initWithContentsOfFileByMDMHook:(NSString *)path;
- (instancetype)initWithDataByMDMHook:(NSData *)data scale:(CGFloat)scale;

@end

@implementation YYImage (MDMImageHook)

- (instancetype)initWithContentsOfFileByMDMHook:(NSString *)path
{
    if (path == nil ||
        path.length == 0) {
        return nil;
    }
    
    BOOL callOriginal = YES;
    if ([self isMemberOfClass:[YYImage class]]) {
        MDMImageDecoder *decoder = [MDMImageDecoder decoderWithFile:path];
        if (decoder) {
            YYImage *image = [[MDMImage alloc] initWithImageDecoder:decoder scale:1.0];
            if (image) {
                self = image;
                callOriginal = NO;
            }
        }
    }
    
    if (callOriginal == YES) {
        self = [self initWithContentsOfFileByMDMHook:path];
    }
    
    return self;
}

- (instancetype)initWithDataByMDMHook:(NSData *)data scale:(CGFloat)scale
{
    BOOL callOriginal = YES;
    if ([self isMemberOfClass:[YYImage class]]) {
        MDMImageDecoder *decoder = [MDMImageDecoder decoderWithData:data];
        if (decoder) {
            YYImage *image = [[MDMImage alloc] initWithImageDecoder:decoder scale:scale];
            if (image) {
                self = image;
                callOriginal = NO;
            }
        }
    }
    
    if (callOriginal == YES) {
        self = [self initWithDataByMDMHook:data scale:scale];
    }
    return self;
}

@end


#pragma mark - MDMImage

@implementation MDMImage

+ (void)load
{
//    return;
    
    Method ori_Method =  class_getInstanceMethod([YYImage class], @selector(initWithData:scale:));
    Method my_Method = class_getInstanceMethod([YYImage class], @selector(initWithDataByMDMHook:scale:));
    const char *oriTypeDescription = (char *)method_getTypeEncoding(ori_Method);
    const char *myTypeDescription = (char *)method_getTypeEncoding(my_Method);
    IMP originalIMP = method_getImplementation(ori_Method);
    IMP myIMP = method_getImplementation(my_Method);
    class_replaceMethod([YYImage class], @selector(initWithData:scale:), myIMP, oriTypeDescription);
    class_replaceMethod([YYImage class], @selector(initWithDataByMDMHook:scale:), originalIMP, myTypeDescription);
    
    Method ori_Method2 =  class_getInstanceMethod([YYImage class], @selector(initWithContentsOfFile:));
    Method my_Method2 = class_getInstanceMethod([YYImage class], @selector(initWithContentsOfFileByMDMHook:));
    const char *oriTypeDescription2 = (char *)method_getTypeEncoding(ori_Method2);
    const char *myTypeDescription2 = (char *)method_getTypeEncoding(my_Method2);
    IMP originalIMP2 = method_getImplementation(ori_Method2);
    IMP myIMP2 = method_getImplementation(my_Method2);
    class_replaceMethod([YYImage class], @selector(initWithContentsOfFile:), myIMP2, oriTypeDescription2);
    class_replaceMethod([YYImage class], @selector(initWithContentsOfFileByMDMHook:), originalIMP2, myTypeDescription2);
}

- (instancetype)initWithImageDecoder:(id)imageDecoder scale:(CGFloat)scale
{
    if ([imageDecoder isKindOfClass:[MDMImageDecoder class]]) {
        UIImage *firstImage = [imageDecoder imageFrameAtIndex:0];
        if (firstImage == nil) {
            return nil;
        }
        
        self = [self initWithCGImage:firstImage.CGImage scale:scale orientation:firstImage.imageOrientation];
        if (self == nil) {
            return nil;
        }
        
        self.imageDecoder = imageDecoder;
        self.handleBySelf = YES;
        self.yy_isDecodedForDisplay = YES;
        return self;
    }
    
    return nil;
}


#pragma mark YYAnimatedImage(protocol)

- (NSUInteger)animatedImageLoopCount
{
    if (self.handleBySelf) {
        return self.imageDecoder.loopCount;
    } else {
        return [super animatedImageLoopCount];
    }
}

- (NSUInteger)animatedImageFrameCount
{
    if (self.handleBySelf) {
        return self.imageDecoder.frameCount;
    } else {
        return [super animatedImageFrameCount];
    }
}

- (NSUInteger)animatedImageBytesPerFrame
{
    if (self.handleBySelf) {
        return self.imageDecoder.imageBytesPerFrame;
    } else {
        return [super animatedImageBytesPerFrame];
    }
}

- (UIImage *)animatedImageFrameAtIndex:(NSUInteger)index
{
    if (self.handleBySelf) {
        UIImage *image = [self.imageDecoder imageFrameAtIndex:index];
        image.yy_isDecodedForDisplay = YES;
        return image;
    } else {
        return [super animatedImageFrameAtIndex:index];
    }
}

- (NSTimeInterval)animatedImageDurationAtIndex:(NSUInteger)index
{
    if (self.handleBySelf) {
        NSTimeInterval duration = [self.imageDecoder frameDurationAtIndex:index];
        if (duration < 0.011f) {
            return 0.100f;
        }
        return duration;
    } else {
        return [super animatedImageDurationAtIndex:index];
    }
}

@end
