//
//  ViewController.mm
//  ArmKeyBoard
//
//  Created by tangkk on 26/10/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "ViewController.h"
#import <MobileCoreServices/UTCoreTypes.h>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#import "opencv2/opencv.hpp"

//#define CANNY

using namespace std;

@interface ViewController () {
    // Drawing Elements
    UIBezierPath *path;
    CGPoint PPoint;
    CGPoint lastPoint;
    CGFloat brush;
    
    // threshold
    int thresh ;
    int max_thresh;
    // minimum area of a contour
    int contourmin;
    int max_contourmin;
    // The contours and hulls
    vector<vector<cv::Point> > mycontours;
    vector<vector<cv::Point> > myhulls;
    
    // Image : Screen Ratio
    float widthRatio;
    float heightRatio;
    float distRatio;
}
@property (strong, nonatomic) IBOutlet UIImageView *mainImage;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Initialize opencv variables
    thresh = 100;
    max_thresh = 255;
    contourmin = 50;
    max_contourmin = 2000;
    
    widthRatio = 1;
    heightRatio = 1;
    distRatio = 1;
    
    // Initialize drawing variables
    brush = 2;
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(clearImage)]];
}

- (cv::Mat)cvMatFromUIImage:(UIImage *)image
{
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(image.CGImage);
    CGFloat cols = image.size.width;
    CGFloat rows = image.size.height;
    
    cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
    
    CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to  data
                                                    cols,                       // Width of bitmap
                                                    rows,                       // Height of bitmap
                                                    8,                          // Bits per component
                                                    cvMat.step[0],              // Bytes per row
                                                    colorSpace,                 // Colorspace
                                                    kCGImageAlphaNoneSkipLast |
                                                    kCGBitmapByteOrderDefault); // Bitmap info flags
    
    CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), image.CGImage);
    CGContextRelease(contextRef);
    CGColorSpaceRelease(colorSpace);
    
    return cvMat;
}

-(UIImage *)UIImageFromCVMat:(cv::Mat)cvMat
{
    NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize()*cvMat.total()];
    CGColorSpaceRef colorSpace;
    
    if (cvMat.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    // Creating CGImage from cv::Mat
    CGImageRef imageRef = CGImageCreate(cvMat.cols,                                 //width
                                        cvMat.rows,                                 //height
                                        8,                                          //bits per component
                                        8 * cvMat.elemSize(),                       //bits per pixel
                                        cvMat.step[0],                            //bytesPerRow
                                        colorSpace,                                 //colorspace
                                        kCGImageAlphaNone|kCGBitmapByteOrderDefault,// bitmap info
                                        provider,                                   //CGDataProviderRef
                                        NULL,                                       //decode
                                        false,                                      //should interpolate
                                        kCGRenderingIntentDefault                   //intent
                                        );
    
    
    // Getting UIImage from CGImage
    UIImage *finalImage = [UIImage imageWithCGImage:imageRef];
    CGImageRelease(imageRef);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return finalImage;
}

// FIXME: The smallest size of the hull should be consistent on the screen no matter how large of how small the image is
-(void) doContourOperationTarget: (cv::Mat &)targtImg  Src:(cv::Mat &)srcImg Mix:(cv::Mat &)mixImg{
    cv::Mat threshold_output;
    cv::Mat canny_output;
    cv::Mat contourdrawing;
    // tangkk - Contours are a vector of vector of points
    vector<vector<cv::Point> > contours;
    
    // tangkk - So Vec4i may indicates 4 entries in each elements of the vector?
    vector<cv::Vec4i> hierarchy;
    
    
    //make sure there's exactly 20 contours extracted from the source
    thresh = 100;
    do {
        /*************************Find and draw each contour********************************/
        contours.clear();
        
#ifdef CANNY
        cv::Canny( targtImg, canny_output, thresh, thresh*2, 3 );
        findContours( canny_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
        contourdrawing = cv::Mat::zeros( canny_output.size(), CV_8UC4 );
#else
        cv::threshold( targtImg, threshold_output, thresh, 255, cv::THRESH_BINARY );
        findContours( threshold_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
        contourdrawing = cv::Mat::zeros( threshold_output.size(), CV_8UC4 );
#endif
        
        //discard the small contours until there are 20 left
        contourmin = 50;
        do {
            mycontours.clear();
            for( int i = 0; i< contours.size(); i++) {
                double area = contourArea(contours[i]);
                if (area > contourmin)
                    mycontours.push_back(contours[i]);
            }
            contourmin++;
        } while (mycontours.size() > 20 && contourmin < max_contourmin);
        if (mycontours.size() > 20) {
            thresh-=10;
        } else {
            thresh+=10;
        }
        cout << "mycontours.size() = " << mycontours.size() << "\n";
        cout << "thresh = " << thresh << "\n";
        cout << "contourmin = " << contourmin << "\n";
    } while ((mycontours.size() < 20 && thresh > 5) || (mycontours.size() > 20 && thresh < max_thresh));
    cout << "final mycontours.size() = " << mycontours.size() << "\n";
    cout << "final thresh = " << thresh << "\n";
    cout << "final contourmin = " << contourmin << "\n";
    
    cv::RNG rng(12345);
    for( int i = 0; i< mycontours.size(); i++ ) {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        cv::drawContours( contourdrawing, mycontours, i, color, 1, 8, hierarchy, 0, cv::Point() );
    }
    
    
    for( int i = 0; i< mycontours.size(); i++ ) {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        cv::drawContours( contourdrawing, mycontours, i, color, 1, 8, hierarchy, 0, cv::Point() );
    }
    
    /*************************Find the convex hull object for each contour********************************/
    myhulls.clear();
    vector<vector<cv::Point> >hull( mycontours.size() );
    for( size_t i = 0; i < mycontours.size(); i++ ) {
        cv::convexHull( cv::Mat(mycontours[i]), hull[i], false );
        myhulls.push_back(hull[i]);
    }
    
    /// Draw contours + hull results
    cv::Mat drawing;
#ifdef CANNY
    drawing = cv::Mat::zeros( canny_output.size(), CV_8UC4 );
#else
    drawing = cv::Mat::zeros( threshold_output.size(), CV_8UC4 );
#endif
    for( size_t i = 0; i< mycontours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        cv::drawContours( drawing, myhulls, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
    
    for( size_t i = 0; i< mycontours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255)  );
        cv::drawContours( drawing, myhulls, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
    
    
    /*************************Mix the source and the drawings********************************/
    double alpha, beta;
    alpha = 0.5;
    beta = 1 - alpha;
    cv::addWeighted(srcImg, alpha, drawing, beta, 0, mixImg);
    
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
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerOriginalImage];
        // Set the display content mode
        _mainImage.contentMode = UIViewContentModeScaleAspectFit;
        //_mainImage.contentMode = UIViewContentModeScaleAspectFill;
        
        cout << "image size x = " << selectedImage.size.width << " y= " << selectedImage.size.height << "\n";
        cout << "screen size x = " << self.view.frame.size.width << " y=" << self.view.frame.size.height << "\n";
        widthRatio = selectedImage.size.width / self.view.frame.size.width;
        heightRatio = selectedImage.size.height / self.view.frame.size.height;
        distRatio = sqrt(widthRatio*widthRatio + heightRatio*heightRatio);
        cout << "widthRatio = " << widthRatio  << "\n";
        cout << "heightRatio = " << heightRatio << "\n";
        cout << "distRatio = " << distRatio << "\n";
        
        // Do Image processing using opencv here;
        _mainImage.image = [self ConvexHullProcessSrcImage:selectedImage];
        
        //_mainImage.image = selectedImage;
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (UIImage *) ConvexHullProcessSrcImage:(UIImage *) SrcImg {
    cv::Mat src = [self cvMatFromUIImage:SrcImg];
    cv::Mat src_gray;
    cv::Mat mix;
    
    cv::cvtColor( src, src_gray, cv::COLOR_BGR2GRAY );
    cv::blur( src_gray, src_gray, cv::Size(3,3) );
    [self doContourOperationTarget:src_gray Src:src Mix:mix];
    return [self UIImageFromCVMat:mix];
}

// Drawing methods
//static CGPoint midPoint(CGPoint p0, CGPoint p1) {
//    return CGPointMake((p0.x + p1.x)/2, (p0.y + p1.y)/2);
//}

- (void) checkInHullPosX:(int)x Y:(int)y {
    bool isInHull = false;
    float dist;
    int scaleX, scaleY;
    scaleX = x*widthRatio;
    scaleY = y*heightRatio;
    
    //FIXME: Please fix it through scaling by the ratio between image size and screen size
    for (int i = 0; i < myhulls.size(); i++) {
        dist = (float)cv::pointPolygonTest( myhulls[i], cv::Point2f(scaleX,scaleY), true );
        
        // FIXME: what about the distance, should it also be scaled down?
        if(dist > 0) {
            dist /= distRatio; //Scale down the dist
            cout << "The current pos is in Hull " << i << " with distance " << dist << "\n";
            isInHull = true;
        }
    }
    if (!isInHull) {
        cout << "The current pos is outside " << "\n";
    }
    cout << "current pos x = " << x << " y = " << y << "\n";
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    [self checkInHullPosX:lastPoint.x Y:lastPoint.y];
//    path = [UIBezierPath bezierPath];
//    [path moveToPoint:lastPoint];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
//    UITouch *touch = [touches anyObject];
//    CGPoint currentPoint = [touch locationInView:self.view];
//
//    CGPoint middlePoint = midPoint(lastPoint, currentPoint);
//    [path addQuadCurveToPoint:middlePoint controlPoint:lastPoint];
//    
//    UIGraphicsBeginImageContext(self.view.frame.size);
//    [self.mainImage.image drawInRect:CGRectMake(0, 0, self.mainImage.frame.size.width, self.mainImage.frame.size.height)];
//    [[UIColor blackColor] setStroke];
//    [path setLineWidth:brush];
//    [path stroke];
//    CGContextAddPath(UIGraphicsGetCurrentContext(), path.CGPath);
//    self.mainImage.image = UIGraphicsGetImageFromCurrentImageContext();
//    UIGraphicsEndImageContext();
//    
//    lastPoint = currentPoint;
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
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
