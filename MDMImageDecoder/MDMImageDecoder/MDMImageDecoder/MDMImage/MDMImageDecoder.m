//
//  MDMImageDecoder.m
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/20.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "MDMImageDecoder.h"
#import "MDMMMAPUtil.h"
#import "MDMGIFImageDecoder.h"
#import "MDMPNGImageDecoder.h"
#import "YYImage.h"

@implementation MDMImageDecoder

+ (instancetype)decoderWithFile:(NSString *)file
{
    void *buffer = NULL;
    size_t size = [MDMMMAPUtil openImageFileByMMAP:file destBuffer:&buffer];
    
    CFDataRef dataRef = CFDataCreate(kCFAllocatorDefault, buffer, size);
    if (dataRef == NULL) {
        return nil;
    }
    YYImageType type = YYImageDetectType(dataRef);
    CFRelease(dataRef);
    
    MDMImageDecoder *imageDecoder = [self decoderWithType:type];
    
    if (imageDecoder == nil) {
        return nil;
    }
    
    imageDecoder->_imageDataBuffer = buffer;
    imageDecoder->_imageDataBufferSize = size;
    imageDecoder->_imageDataBufferFile = nil;
    
    if ([imageDecoder preloadImageInfo] == NO) {
        return nil;
    }
    
    return imageDecoder;
}

+ (instancetype)decoderWithData:(NSData *)data
{
    NSString *file = [NSString stringWithFormat:@"original_data_%zd", [data hash]];
    void *buffer = [MDMMMAPUtil createMMAPFile:file size:data.length];
    if (buffer == NULL) {
        return nil;
    }
    
    YYImageType type = YYImageDetectType((__bridge CFDataRef)data);
    
    MDMImageDecoder *imageDecoder = [self decoderWithType:type];
    
    if (imageDecoder == nil) {
        return nil;
    }
    
    imageDecoder->_imageDataBuffer = buffer;
    imageDecoder->_imageDataBufferSize = data.length;
    imageDecoder->_imageDataBufferFile = file;
    
    memcpy(imageDecoder->_imageDataBuffer, data.bytes, data.length);
    
    if ([imageDecoder preloadImageInfo] == NO) {
        return nil;
    }
    
    return imageDecoder;
    
}

+ (instancetype)decoderWithType:(YYImageType)imageType
{
    MDMImageDecoder *imageDecoder = nil;
    switch (imageType) {
        case YYImageTypeGIF:
            imageDecoder = [[MDMGIFImageDecoder alloc] init];
            break;
        case YYImageTypePNG:
            imageDecoder = [[MDMPNGImageDecoder alloc] init];
            break;
        default:
            break;
    }
    return imageDecoder;
}

- (void)dealloc
{
    [MDMMMAPUtil cleanMMAPFile:_imageDataBufferFile buffer:_imageDataBuffer size:_imageDataBufferSize];
}


#pragma mark - public

- (BOOL)preloadImageInfo
{
    return NO;
}

- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index
{
    return 0;
}

- (UIImage *)imageFrameAtIndex:(NSUInteger)index
{
    return nil;
}

@end
