//
//  ViewController.m
//  ArmKeyBoard
//
//  Created by tangkk on 26/10/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>

@interface ViewController () {
    // Drawing Elements
    UIBezierPath *path;
    CGPoint PPoint;
    CGPoint lastPoint;
    CGFloat brush;
}
@property (strong, nonatomic) IBOutlet UIImageView *mainImage;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    brush = 2;
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(clearImage)]];
}

// Photo Picking methods
- (BOOL) startMediaBrowserFromViewController: (UIViewController *)controller
                               usingDelegate:(id <UIImagePickerControllerDelegate, UINavigationControllerDelegate>) delegate {
    
    if (([UIImagePickerController isSourceTypeAvailable:
          UIImagePickerControllerSourceTypeSavedPhotosAlbum] == NO)
         || (delegate == nil)
         || (controller == nil)) {
        return NO;
    }
    
    UIImagePickerController *mediaUI = [[UIImagePickerController alloc] init];
    mediaUI.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    mediaUI.mediaTypes = [[NSArray alloc] initWithObjects:(NSString *) kUTTypeImage, nil]; //Only Images are allowed
    mediaUI.allowsEditing = NO;
    mediaUI.delegate = delegate;
    
    [controller presentViewController:mediaUI animated:YES completion:nil];
    return YES;
}

// FIXME: Why is the warning here?
- (IBAction)showImageBrowser:(id)sender {
    NSLog(@"Action Called");
    [self startMediaBrowserFromViewController:self usingDelegate:self];
}

// Delegate method for the pick controller media browser
- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSLog(@"delegate called!");
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    UIImage *selectedImage;
    
    // Handle the original image only
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo)
        selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerOriginalImage];
    
    // Display the image
    _mainImage.image = selectedImage;
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

// Drawing methods
static CGPoint midPoint(CGPoint p0, CGPoint p1) {
    return CGPointMake((p0.x + p1.x)/2, (p0.y + p1.y)/2);
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    path = [UIBezierPath bezierPath];
    [path moveToPoint:lastPoint];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentPoint = [touch locationInView:self.view];
    
    CGPoint middlePoint = midPoint(lastPoint, currentPoint);
    [path addQuadCurveToPoint:middlePoint controlPoint:lastPoint];
    
    UIGraphicsBeginImageContext(self.view.frame.size);
    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.mainImage.frame.size.width, self.mainImage.frame.size.height)];
    [[UIColor blackColor] setStroke];
    [path setLineWidth:brush];
    [path stroke];
    CGContextAddPath(UIGraphicsGetCurrentContext(), path.CGPath);
    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    lastPoint = currentPoint;
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Perform auto stretching to the boarder of the screen
//    UITouch *touch = [touches anyObject];
//    CGPoint currentPoint = [touch locationInView:self.view];
//    CGFloat deltaX, deltaY;
//    deltaX = currentPoint.x - lastPoint.x;
//    deltaY = currentPoint.y - lastPoint.y;
//    
//    /*
//    // draw shape
//    [path closePath];
//    
//    // draw line
//    while (currentPoint.x > 0 && currentPoint.x < self.mainImage.frame.size.width && currentPoint.y > 0 && currentPoint.y < self.mainImage.frame.size.height) {
//        [path addLineToPoint:currentPoint];
//        currentPoint.x += deltaX;
//        currentPoint.y += deltaY;
//    }
//     */
//    
//    UIGraphicsBeginImageContext(self.view.frame.size);
//    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.mainImage.frame.size.width, self.mainImage.frame.size.height)];
//    [[UIColor blackColor] setStroke];
//    [path setLineWidth:brush];
//    [path stroke];
//    CGContextAddPath(UIGraphicsGetCurrentContext(), path.CGPath);
//    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
    
}

- (void) clearImage {
    path = [UIBezierPath bezierPath];
    self.mainImage.image = nil;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
