//
//  Drawing.h
//  PlayerMachine
//
//  Created by tangkk on 17/8/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface Drawing : UIViewController

+ (void) drawCircleWithCenter:(CGPoint)center Radius:(CGFloat)radius onContext:(CGContextRef)ctx withbrush:(UInt16)brush
                          Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size;

+ (void) drawLineWithPreviousPoint:(CGPoint)PP CurrentPoint:(CGPoint)CP onContext:(CGContextRef)ctx withbrush:(UInt16)brush
                               Red:(CGFloat)red Green:(CGFloat)green Blue:(CGFloat)blue Alpha:(CGFloat)opacity Size:(CGSize)size;

@end

