//
//  ViewController.h
//  ArmKeyBoard
//
//  Created by tangkk on 26/10/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DirectoryWatcher.h"

@interface ViewController : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIPickerViewDataSource, UIPickerViewDelegate,DirectoryWatcherDelegate>

@end
