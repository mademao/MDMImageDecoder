//
//  MDMImageDecoder.h
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/20.
//  Copyright © 2019 mademao. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MDMImageDecoder : NSObject {
    // 原始数据相关
    // 1. 如果是通过 NSData 初始化，创建一个 mmap 文件，将 NSData 复制一份
    // 2. 如果是通过 FilePath 初始化，直接以 mmap 方式加载文件内容
    void *_imageDataBuffer;
    size_t _imageDataBufferSize;
    NSString *_imageDataBufferFile; // _imageDataBuffer 对应的 mmap 文件，如果是通过 FilePath 初始化，此值为 nil
}

@property (nonatomic, assign) NSUInteger loopCount;
@property (nonatomic, assign) NSUInteger frameCount;
@property (nonatomic, assign) NSUInteger imageBytesPerFrame;

+ (instancetype)decoderWithFile:(NSString *)file;
+ (instancetype)decoderWithData:(NSData *)data;

- (BOOL)preloadImageInfo;
- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index;
- (UIImage *)imageFrameAtIndex:(NSUInteger)index;

@end

NS_ASSUME_NONNULL_END
