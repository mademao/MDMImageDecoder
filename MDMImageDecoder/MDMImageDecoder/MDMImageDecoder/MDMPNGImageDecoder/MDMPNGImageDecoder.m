//
//  MDMPNGImageDecoder.m
//  GIFDecodeDemo
//
//  Created by mademao on 2019/3/20.
//  Copyright © 2019 mademao. All rights reserved.
//

#import "MDMPNGImageDecoder.h"
#import "MDMMMAPUtil.h"
#import "png.h"
#import <pthread.h>

static const int PNGSignatureLength = 8;


#pragma mark - MDMPNGReaderOffsetManager

@interface MDMPNGReaderOffsetManager : NSObject

@property (nonatomic, strong) NSMutableDictionary *offsetDict;

+ (instancetype)sharedManager;

@end

@implementation MDMPNGReaderOffsetManager

+ (instancetype)sharedManager
{
    static MDMPNGReaderOffsetManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[MDMPNGReaderOffsetManager alloc] init];
        manager.offsetDict = [NSMutableDictionary dictionary];
    });
    return manager;
}

- (void)updateOffset:(size_t)offset forPNGPtr:(png_structp)ptr
{
    NSNumber *ptrNum = [NSNumber numberWithLongLong:(long long)ptr];
    NSNumber *offsetNum = [NSNumber numberWithUnsignedLong:offset];
    if (ptrNum) {
        [self.offsetDict setObject:offsetNum forKey:ptrNum];
    }
}

- (size_t)offsetOfPNGPtr:(png_structp)ptr
{
    size_t offset = 0;
    NSNumber *ptrNum = [NSNumber numberWithLongLong:(long long)ptr];
    if (ptrNum) {
        offset = [[self.offsetDict objectForKey:ptrNum] unsignedLongValue];
    }
    return offset;
}

@end

void read_png(png_structp png_ptr, png_bytep data, png_size_t len)
{
    char *input;
    input = png_get_io_ptr(png_ptr);
    size_t offset = [[MDMPNGReaderOffsetManager sharedManager] offsetOfPNGPtr:png_ptr];
    memcpy(data, input + offset, len);
    [[MDMPNGReaderOffsetManager sharedManager] updateOffset:(offset + len) forPNGPtr:png_ptr];
}


#pragma mark - MDMPNGImageDecoder

@interface MDMPNGImageDecoder () {
    pthread_mutex_t _lock;
    
    // 解码相关
    CGContextRef _context;
    png_bytep _contextBuffer;
    NSString *_contextBufferFile;
    
    int _width;
    int _height;
    int _bytesPerRows;
}

@end

@implementation MDMPNGImageDecoder

- (void)dealloc
{
    if (_context) {
        CGContextRelease(_context);
    }
    
    [MDMMMAPUtil cleanMMAPFile:_contextBufferFile buffer:_contextBuffer size:self.imageBytesPerFrame * self.frameCount];
}

#pragma mark private

- (BOOL)preloadPNGImageInfo
{
    self.loopCount = 1;
    self.frameCount = 1;
    return YES;
}

- (BOOL)createContextBuffer
{
    _bytesPerRows = (int)MDMByteAlignForCoreAnimation(_width * 4);
    self.imageBytesPerFrame = _bytesPerRows * _height;
    
    NSString *file = [NSString stringWithFormat:@"sgi_png_context_%zd", [self hash]];
    size_t size = self.imageBytesPerFrame * self.frameCount;
    void *buffer = [MDMMMAPUtil createMMAPFile:file size:size];
    if (buffer == NULL) {
        return NO;
    }
    _contextBuffer = buffer;
    _contextBufferFile = file;
    
    memset(_contextBuffer, 0, size);
    
    return YES;
}


#pragma mark next image

- (UIImage *)nextImage
{
    if (_context == NULL) {
        png_structp png_ptr = NULL;
        png_infop info_ptr = NULL;
        png_uint_32 width = 0, height = 0;
        int bit_depth = 0, color_type = 0, number_of_passes = 0;
        
        png_ptr = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
        if (png_ptr == NULL) {
            return nil;
        }
        
        info_ptr = png_create_info_struct(png_ptr);
        if (info_ptr == NULL) {
            png_destroy_read_struct(&png_ptr, NULL, NULL);
            return nil;
        }
        
        const unsigned char header[PNGSignatureLength];
        memcpy((void *)header, self->_imageDataBuffer, PNGSignatureLength);
        if (png_sig_cmp(header, 0, PNGSignatureLength)) {
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            return nil;
        }
        
        [[MDMPNGReaderOffsetManager sharedManager] updateOffset:0 forPNGPtr:png_ptr];
        
        if (setjmp(png_jmpbuf(png_ptr))) {
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            return nil;
        }
        
        png_set_read_fn(png_ptr, (void *)self->_imageDataBuffer, read_png);
        
        png_read_info(png_ptr, info_ptr);
        width = png_get_image_width(png_ptr, info_ptr);
        height = png_get_image_height(png_ptr, info_ptr);
        color_type = png_get_color_type(png_ptr, info_ptr);
        bit_depth = png_get_bit_depth(png_ptr, info_ptr);
        number_of_passes = png_set_interlace_handling(png_ptr);
        
        if (bit_depth == 16) {
            png_set_strip_16(png_ptr);
        }
        if (color_type == PNG_COLOR_TYPE_PALETTE) {
            png_set_expand(png_ptr);
        }
        if (bit_depth < 8) {
            png_set_expand(png_ptr);
        }
        if (png_get_valid(png_ptr, info_ptr, PNG_INFO_tRNS)) {
            png_set_expand(png_ptr);
        }
        if (color_type == PNG_COLOR_TYPE_GRAY ||
            color_type == PNG_COLOR_TYPE_GRAY_ALPHA) {
            png_set_gray_to_rgb(png_ptr);
        }
        png_read_update_info(png_ptr, info_ptr);
        
        color_type = png_get_color_type(png_ptr, info_ptr);
        BOOL hasAlpha = (color_type & PNG_COLOR_MASK_ALPHA);
        
        _width = width;
        _height = height;
        if (_contextBuffer == NULL &&
            [self createContextBuffer] == NO) {
            png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
            return nil;
        }
        
        png_bytep pSingleRow = NULL;
        if (hasAlpha == NO) {
            pSingleRow = (png_bytep)calloc(_bytesPerRows, sizeof(png_bytep));
        }
        for (int h = 0; h < height; h++) {
            if (hasAlpha == YES) {
                pSingleRow = _contextBuffer + h * _bytesPerRows;
            }
            
            png_read_rows(png_ptr, &pSingleRow, NULL, 1);
            
            if (hasAlpha == YES) {
                for (int i = 0; i < _bytesPerRows; i = i + 4) {
                    int index = i + h * _bytesPerRows;
                    int alpha = _contextBuffer[index + 3];
                    _contextBuffer[index] *= (alpha / 255.0);
                    _contextBuffer[index + 1] *= (alpha / 255.0);
                    _contextBuffer[index + 2] *= (alpha / 255.0);
                }
            } else {
                int rowbytes = (int)png_get_rowbytes(png_ptr, info_ptr);
                int index = 0;
                for (int i = 0; i < rowbytes; i++) {
                    _contextBuffer[index + h * _bytesPerRows] = pSingleRow[i];
                    index++;
                    if ((i + 1) % 3 == 0) {
                        _contextBuffer[index + h * _bytesPerRows] = 0;
                        index++;
                    }
                }
            }
        }
        
        if (hasAlpha == NO &&
            pSingleRow != NULL) {
            free(pSingleRow);
        }
        
        png_read_end(png_ptr, info_ptr);
        png_destroy_read_struct(&png_ptr, &info_ptr, NULL);
        
        CGImageAlphaInfo alphaInfo = hasAlpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast;
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault | alphaInfo;
        _context = CGBitmapContextCreate(_contextBuffer,
                                         _width,
                                         _height,
                                         8,
                                         _bytesPerRows,
                                         CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo);
        if (_context == NULL) {
            return nil;
        }
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(_context);
    UIImage *image = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    return image;
}


#pragma mark public

- (BOOL)preloadImageInfo
{
    if ([self preloadPNGImageInfo] == NO) {
        return NO;
    }

    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_lock, &attr);
    pthread_mutexattr_destroy(&attr);
    return YES;
}

- (NSTimeInterval)frameDurationAtIndex:(NSUInteger)index
{
    return 0;
}

- (UIImage *)imageFrameAtIndex:(NSUInteger)index
{
    if (index >= self.frameCount) {
        return nil;
    }
    
    pthread_mutex_lock(&_lock);
    UIImage *image = [self nextImage];
    pthread_mutex_unlock(&_lock);
    return image;
}

@end
