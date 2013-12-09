//
//  HierarchicalScale.h
//  ArmKeyBoard
//
//  Created by tangkk on 8/12/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import <Foundation/Foundation.h>

/******note degree to midi note degree******
 1 -> 0
 b2 -> 1
 2 -> 2
 b3 -> 3
 3 -> 4
 4 -> 5
 #4 -> 6
 5 -> 7
 b6 -> 8
 6 -> 9
 b7 -> 10
 7 -> 11
 1' -> 12
 b2' -> 13
 2' -> 14
 b3' -> 15
 3' -> 16
 4' -> 17
 #4' -> 18
 5' -> 19
 b6' -> 20
 6' -> 21
 b7' -> 22
 7' -> 23
 1'' -> 24
 ********************************/

@interface HierarchicalScale : NSObject

- (NSArray *) getScale:(NSString *)scaleName;

@end
