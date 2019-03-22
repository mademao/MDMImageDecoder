//
//  MDMGIFImageDecoder.m
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/20.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "MDMGIFImageDecoder.h"
#import "GifDecode.h"
#import <pthread.h>
#import "MDMMMAPUtil.h"
#import <sys/mman.h>

@interface MDMGIFImageDecoder () {
    pthread_mutex_t _lock;
    
    // giflib相关
    GifFileType *_gifFileType;
    GifRowType _gifRowType;
    GraphicsControlBlock _graphicsControlBlock;
    
    // 解码相关
    CGContextRef *_contextRefArray;
    PixelRGBA *_contextBuffer;
    NSString *_contextBufferFile;
    
    long _dataHeadOffset;   // 保存 Gif 第一帧图像数据的位置偏移
    NSInteger _currentIndexToDecode;   // 保存当前待解码的位置
    NSArray * _frameDurationArray;
    
    long _currentDataOffset;
    UIImage * _lastDecodedImage;
}

- (int)readImageData:(GifByteType *)buf byLength:(int)length;

@end

static int GIFDataReadFunc(GifFileType *fileType, GifByteType *buf, int len)
{
    MDMGIFImageDecoder *decoder = (__bridge MDMGIFImageDecoder *)(fileType->UserData);
    return [decoder readImageData:buf byLength:len];
}

@implementation MDMGIFImageDecoder

#pragma mark dealloc

- (void)dealloc
{
    if (_gifFileType) {
        DGifCloseFile(_gifFileType, NULL);
    }
    
    if (_gifRowType) {
        free(_gifRowType);
    }
    
    if (_contextRefArray) {
        for (NSUInteger i = 0; i < self.frameCount; i++) {
            CGContextRef context = _contextRefArray[i];
            CGContextRelease(context);
        }
        free(_contextRefArray);
    }
    
    [MDMMMAPUtil cleanMMAPFile:_contextBufferFile buffer:_contextBuffer size:self.imageBytesPerFrame * self.frameCount];
    
    pthread_mutex_destroy(&_lock);
}

#pragma mark private

- (void)resetGIFDataOffset
{
    _currentDataOffset = _dataHeadOffset;
}

- (int)readImageData:(GifByteType *)buf byLength:(int)length
{
    int actualLength = MIN(length, (int)(_imageDataBufferSize - _currentDataOffset));
    memcpy(buf, _imageDataBuffer + _currentDataOffset, actualLength);
    _currentDataOffset += actualLength;
    return actualLength;
}

- (BOOL)preloadGIFImageInfo
{
    int loopCount = 0;
    int frameCount = 0;
    
    NSMutableArray *durationArray = [NSMutableArray array];
    int errorCode = 0;
    GifRecordType recordType;
    
    _graphicsControlBlock.DelayTime = 0;
    _graphicsControlBlock.TransparentColor = -1;
    _graphicsControlBlock.DisposalMode = DISPOSAL_UNSPECIFIED;
    
    self.imageBytesPerFrame = (NSUInteger)MDMByteAlignForCoreAnimation(_gifFileType->SWidth * 4) * _gifFileType->SHeight;
    
    do {
        if (DGifGetRecordType(_gifFileType, &recordType) == GIF_ERROR) {
            errorCode = _gifFileType->Error;
            goto END;
        }
        
        switch (recordType) {
            case EXTENSION_RECORD_TYPE:{
                GifByteType *gifExtBuffer;
                int gifExtCode;
                if (DGifGetExtension(_gifFileType, &gifExtCode, &gifExtBuffer) == GIF_ERROR) {
                    errorCode = _gifFileType->Error;
                    goto END;
                }
                
                if (gifExtCode == GRAPHICS_EXT_FUNC_CODE && gifExtBuffer[0] == 4) {
                    DGifExtensionToGCB(4, &gifExtBuffer[1], &_graphicsControlBlock);
                    [durationArray addObject:@(_graphicsControlBlock.DelayTime * 0.01f)];
                }
                
                while (gifExtBuffer != NULL) {
                    if (DGifGetExtensionNext(_gifFileType, &gifExtBuffer) == GIF_ERROR) {
                        errorCode = _gifFileType->Error;
                        goto END;
                    }
                    
                    if (gifExtBuffer && gifExtCode == APPLICATION_EXT_FUNC_CODE && gifExtBuffer[0] == 3 && gifExtBuffer[1] == 1) {
                        loopCount = INT_2_BYTES(gifExtBuffer[2], gifExtBuffer[3]);
                    }
                }
                
                break;
            }
            case IMAGE_DESC_RECORD_TYPE: {
                if (DGifShiftImageDataWithoutDecode(_gifFileType) == GIF_ERROR) {
                    errorCode = _gifFileType->Error;
                    goto END;
                }
                
                frameCount++;
                
                while (durationArray.count < frameCount) {
                    [durationArray addObject:@(0.0f)];
                }
                
                break;
            }
            case TERMINATE_RECORD_TYPE:
            {
                [self resetGIFDataOffset];
                
                break;
            }
            default:
                break;
        }
    } while (recordType != TERMINATE_RECORD_TYPE);
    
END:
    if (errorCode) {
        return NO;
    }
    
    self.loopCount = loopCount;
    self.frameCount = frameCount;
    _frameDurationArray = [NSArray arrayWithArray:durationArray];
    return YES;
}


#pragma mark next image

- (UIImage *)nextImage
{
    if (_gifRowType == NULL) {
        _gifRowType = (GifRowType)malloc(_gifFileType->SWidth * sizeof(GifPixelType));
        
        for (NSUInteger i = 0; i < _gifFileType->SWidth; i++) {
            _gifRowType[i] = _gifFileType->SBackGroundColor;
        }
    }
    
    UIImage *retImage = nil;
    int errorCode = 0;
    NSLog(@"decode-->%@", @(_currentIndexToDecode));
    void *contextBuffer = (void *)_contextBuffer + self.imageBytesPerFrame * _currentIndexToDecode;
    CGContextRef context = _contextRefArray[_currentIndexToDecode];
    if (context == NULL) {
        context = CGBitmapContextCreate(contextBuffer,
                                        _gifFileType->SWidth,
                                        _gifFileType->SHeight,
                                        8,
                                        MDMByteAlignForCoreAnimation(_gifFileType->SWidth * 4),
                                        CGColorSpaceCreateDeviceRGB(),
                                        kCGBitmapByteOrderDefault|kCGImageAlphaPremultipliedLast);
        _contextRefArray[_currentIndexToDecode] = context;
        
        GifRecordType recordType;
        do {
            if (DGifGetRecordType(_gifFileType, &recordType) == GIF_ERROR) {
                errorCode = _gifFileType->Error;
                goto END;
            }
            
            switch (recordType) {
                case EXTENSION_RECORD_TYPE: {
                    GifByteType *gifExtBuffer;
                    int gifExtCode;
                    if (DGifGetExtension(_gifFileType, &gifExtCode, &gifExtBuffer) == GIF_ERROR) {
                        errorCode = _gifFileType->Error;
                        goto END;
                    }
                    if (gifExtCode == GRAPHICS_EXT_FUNC_CODE && gifExtBuffer[0] == 4) {
                        DGifExtensionToGCB(4, &gifExtBuffer[1], &_graphicsControlBlock);
                    }
                    while (gifExtBuffer != NULL) {
                        if (DGifGetExtensionNext(_gifFileType, &gifExtBuffer) == GIF_ERROR) {
                            errorCode = _gifFileType->Error;
                            goto END;
                        }
                    }
                    break;
                }
                case IMAGE_DESC_RECORD_TYPE: {
                    CGImageRef image = NULL;
                    NSLog(@"-->decode %@", @(_graphicsControlBlock.DisposalMode));
//                    if (_graphicsControlBlock.DisposalMode == DISPOSE_DO_NOT) {
                        NSInteger lastIndexDecode = _currentIndexToDecode - 1;
                        if (lastIndexDecode >= 0) {
                            void *lastContextBuffer = (void *)_contextBuffer + self.imageBytesPerFrame * lastIndexDecode;
                            memcpy((void *)contextBuffer, lastContextBuffer, self.imageBytesPerFrame);
                        }
//                    }
                    errorCode = renderGifFrameWithBufferSize(_gifFileType, _gifRowType, context, contextBuffer, _graphicsControlBlock, &image, self.imageBytesPerFrame);
                    if (errorCode) {
                        goto END;
                    }
                    
                    retImage = [UIImage imageWithCGImage:image];
                    CGImageRelease(image);
                    image = NULL;
                    [UIImagePNGRepresentation(retImage) writeToFile:[NSString stringWithFormat:@"/Users/mademao/Desktop/RetImage/%@.png", @(_currentIndexToDecode)] atomically:YES];
                    
                    goto END;
                    
                    break;
                }
                case TERMINATE_RECORD_TYPE: {
                    [self resetGIFDataOffset];
                    recordType = EXTENSION_RECORD_TYPE;
                    break;
                }
                default:
                    break;
            }
        } while (recordType != TERMINATE_RECORD_TYPE);
    } else {
        CGImageRef image = CGBitmapContextCreateImage(context);
        retImage = [UIImage imageWithCGImage:image];
        CGImageRelease(image);
        image = NULL;
        [UIImagePNGRepresentation(retImage) writeToFile:[NSString stringWithFormat:@"/Users/mademao/Desktop/RetImage1/%@.png", @(_currentIndexToDecode)] atomically:YES];
        goto END;
    }
    
END:
    if (errorCode) {
        NSLog(@"------ errorCode : %d", errorCode);
    }
    return retImage;
}


#pragma mark public

- (BOOL)preloadImageInfo
{
    int errorCode = 0;
    _gifFileType = DGifOpen((__bridge void *)self, GIFDataReadFunc, &errorCode);
    if (_gifFileType == NULL) {
        return NO;
    }
    
    _dataHeadOffset = _currentDataOffset;
    if ([self preloadGIFImageInfo] == NO) {
        return NO;
    }
    
    
    NSString *file = [NSString stringWithFormat:@"sgi_gif_context_%zd", [self hash]];
    size_t size = self.imageBytesPerFrame * self.frameCount;
    void *buffer = [MDMMMAPUtil createMMAPFile:file size:size];
    if (buffer == NULL) {
        return NO;
    }
    _contextRefArray = (CGContextRef *)calloc(self.frameCount, sizeof(CGContextRef));
    _contextBuffer = buffer;
    _contextBufferFile = file;
    
    memset(_contextBuffer, 0, size);
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_lock, &attr);
    pthread_mutexattr_destroy(&attr);
    return YES;
}

- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index
{
    if (index > self.frameCount) {
        return 0;
    }
    
    NSTimeInterval duration = [_frameDurationArray[index] doubleValue];
    return duration;
}

- (UIImage *)imageFrameAtIndex:(NSUInteger)index
{
    // 检查 index 是否是当前待解帧
    pthread_mutex_lock(&_lock);
    if (_currentIndexToDecode != index) {
        UIImage *image = _lastDecodedImage;
        pthread_mutex_unlock(&_lock);
        return image;
    }
    
    UIImage *image = [self nextImage];
    _currentIndexToDecode++;
    _lastDecodedImage = image;
    
    if (_currentIndexToDecode >= self.frameCount) {
        [self resetGIFDataOffset];
        _currentIndexToDecode = 0;
    }
    
    pthread_mutex_unlock(&_lock);
    return image;
}

@end
