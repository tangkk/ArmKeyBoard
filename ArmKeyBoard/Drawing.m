//
//  Drawing.m
//  PlayerMachine
//
//  Created by tangkk on 17/8/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "Drawing.h"

@interface Drawing ()

@end

@implementation Drawing

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Drawing Implementation

#pragma mark - Drawing

+ (void) drawCircleWithCenter:(CGPoint)center Radius:(CGFloat)radius onContext:(CGContextRef)ctx withbrush:(UInt16)brush
                          Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity  Size:(CGSize)size{

    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineWidth(ctx, brush);
    CGContextSetRGBStrokeColor(ctx, red, green, blue, opacity);
    //Try drawing a circle
    CGContextAddEllipseInRect(ctx, CGRectMake(center.x-radius, center.y-radius, 2*radius, 2*radius));
    CGContextStrokePath(ctx);
    CGContextFlush(ctx);

}

+ (void) drawLineWithPreviousPoint:(CGPoint)PP CurrentPoint:(CGPoint)CP onContext:(CGContextRef)ctx withbrush:(UInt16)brush
                               Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size{
    //UIGraphicsBeginImageContext(size);
    //[Img.image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    CGContextMoveToPoint(ctx, PP.x, PP.y);
    CGContextAddLineToPoint(ctx, CP.x, CP.y);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineWidth(ctx, brush);
    CGContextSetRGBStrokeColor(ctx, red, green, blue, opacity);
    CGContextSetBlendMode(ctx, kCGBlendModeNormal);
    CGContextStrokePath(ctx);
    //Img.image = UIGraphicsGetImageFromCurrentImageContext();
    //UIGraphicsEndImageContext();
}

@end
