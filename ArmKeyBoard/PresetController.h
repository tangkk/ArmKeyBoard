//
//  PresetController.h
//  ArmKeyBoard
//
//  Created by tangkk on 19/12/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PresetController;
@protocol PresetControllerDelegate <NSObject>

- (void) getPresets: (NSMutableDictionary*)presets from:(PresetController *)controller atRow:(int)row;

@end

@interface PresetController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) id<PresetControllerDelegate> delegate;

@end
