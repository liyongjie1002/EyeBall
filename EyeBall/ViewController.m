//
//  ViewController.m
//  EyeBall
//
//  Created by 李永杰 on 2019/7/2.
//  Copyright © 2019 muheda. All rights reserved.
//

#import "ViewController.h"

#import <CoreImage/CoreImage.h>
#import <QuartzCore/QuartzCore.h>

const CGFloat kRetinaToEyeScaleFactor = 0.5f;
const CGFloat kFaceBoundsToEyeScaleFactor = 4.0f;
@interface ViewController ()

@property (nonatomic, strong) UIImage       *image;
@property (nonatomic, strong) UIImageView   *imageView;

@end

@implementation ViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view addSubview:self.imageView];
}

#pragma mark - Private Methods

- (UIImage *)faceOverlayImageFromImage:(UIImage *)image {
    CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace
                                              context:NULL
                                              options:@{CIDetectorAccuracy : CIDetectorAccuracyHigh}];
    // Get features from the image.
    CIImage *newImage = [CIImage imageWithCGImage:image.CGImage];
    
    NSArray *features = [detector featuresInImage:newImage];
    
    UIGraphicsBeginImageContext(image.size);
    CGRect imageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    
    // Draws this in the upper left coordinate system.
    [image drawInRect:imageRect blendMode:kCGBlendModeNormal alpha:1.0];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (CIFaceFeature *faceFeature in features) {
        CGRect faceRect = [faceFeature bounds];
        CGContextSaveGState(context);
        
        // CI and CG work in different coordinate systems, we should translate to the correct one so we don't get mixed up when calculating the face position.
        CGContextTranslateCTM(context, 0, imageRect.size.height);
        CGContextScaleCTM(context, 1.0, -1.0);
        
        if ([faceFeature hasLeftEyePosition]) {
            CGPoint leftEyePosition = [faceFeature leftEyePosition];
            CGFloat eyeWidth = faceRect.size.width / kFaceBoundsToEyeScaleFactor;
            CGFloat eyeHeight = faceRect.size.height / kFaceBoundsToEyeScaleFactor;
            CGRect eyeRect = CGRectMake(leftEyePosition.x - eyeWidth/2.0f,
                                        leftEyePosition.y - eyeHeight/2.0f,
                                        eyeWidth,
                                        eyeHeight);
            [self drawEyeBallForFrame:eyeRect];
        }
        
        if ([faceFeature hasRightEyePosition]) {
            CGPoint rightEyePosition = [faceFeature rightEyePosition];
            CGRect eyeRect = [self eyeRectWithFaceRect:faceRect eyePosition:rightEyePosition];
            [self drawEyeBallForFrame:eyeRect];
        }
        
        CGContextRestoreGState(context);
    }
    
    UIImage *overlayImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return overlayImage;
}

- (CGRect)eyeRectWithFaceRect:(CGRect)faceRect eyePosition:(CGPoint)eyePosition {
    CGFloat eyeWidth = faceRect.size.width / kFaceBoundsToEyeScaleFactor;
    CGFloat eyeHeight = faceRect.size.height / kFaceBoundsToEyeScaleFactor;
    CGRect eyeRect = CGRectMake(eyePosition.x - eyeWidth/2.0f,
                                eyePosition.y - eyeHeight/2.0f,
                                eyeWidth,
                                eyeHeight);
    return eyeRect;
}

- (CGFloat)faceRotationInRadiansWithLeftEyePoint:(CGPoint)startPoint rightEyePoint:(CGPoint)endPoint {
    CGFloat deltaX = endPoint.x - startPoint.x;
    CGFloat deltaY = endPoint.y - startPoint.y;
    CGFloat angleInRadians = atan2f(deltaY, deltaX);
    return angleInRadians;
}

- (void)drawEyeBallForFrame:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextAddEllipseInRect(context, rect);
    CGContextSetFillColorWithColor(context, [UIColor whiteColor].CGColor);
    CGContextFillPath(context);
    
    CGFloat x, y, eyeSizeWidth, eyeSizeHeight;
    eyeSizeWidth = rect.size.width * kRetinaToEyeScaleFactor;
    eyeSizeHeight = rect.size.height * kRetinaToEyeScaleFactor;
    
    x = arc4random_uniform(rect.size.width - eyeSizeWidth);
    y = arc4random_uniform(rect.size.height - eyeSizeHeight);
    x += rect.origin.x;
    y += rect.origin.y;
    
    CGFloat eyeSize = MIN(eyeSizeWidth, eyeSizeHeight);
    CGRect eyeBallRect = CGRectMake(x, y, eyeSize, eyeSize);
    CGContextAddEllipseInRect(context, eyeBallRect);
    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    CGContextFillPath(context);
}

- (void)fadeInNewImage:(UIImage *)newImage {
    if (@available(iOS 10.0, *)) {
        UIViewPropertyAnimator *animator = [[UIViewPropertyAnimator alloc] initWithDuration:0.75f
                                                                                      curve:UIViewAnimationCurveLinear
                                                                                 animations:^{
                                                                                     self.imageView.image = newImage;
                                                                                 }];
        [animator startAnimation];
    } else {
        
    }
}

-(UIImageView *)imageView {
    if (!_imageView) {
        _imageView = [[UIImageView alloc]initWithFrame:self.view.bounds];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        _imageView.userInteractionEnabled = YES;
    }
    return _imageView;
}

-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
   
    self.image = [UIImage imageNamed:[NSString stringWithFormat:@"%d.jpg",arc4random()%6]];
    self.imageView.image = self.image;
    
    // 1.将代码从主线程移入全局队列，因为是异步执行，不会堵塞主线程。
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        UIImage *overlayImage = [self faceOverlayImageFromImage:self.image];
        
        // 2.目前已经获取到新的照片，在主线程更新UI。
        dispatch_async(dispatch_get_main_queue(), ^{
            [self fadeInNewImage:overlayImage];
        });
    });

}
@end
