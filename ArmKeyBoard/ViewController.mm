//
//  ViewController.mm
//  ArmKeyBoard
//
//  Created by tangkk on 26/10/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "ViewController.h"

// Import the graphics infrastructure
#import <MobileCoreServices/UTCoreTypes.h>
#include <opencv2/core/core.hpp>
#include <opencv2/highgui/highgui.hpp>
#include <opencv2/imgproc/imgproc.hpp>
#import "opencv2/opencv.hpp"

// Import the musical infrastructure
#import "MIDINote.h"
#import "NoteNumDict.h"
#import "VirtualInstrument.h"
#import "AssignmentTable.h"

//#define CANNY
//#define HULL
//#define TEST

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
    cv::Mat srcMat;
    
    // Image : Screen Ratio
    float widthRatio;
    float heightRatio;
    float distRatio;
}

@property (strong, nonatomic) IBOutlet UIImageView *mainImage;

/* Virtual Instrument */
@property (readonly) VirtualInstrument *VI;
@property (readonly) NoteNumDict *Dict;
@property (readonly) AssignmentTable *AST;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    // Initialize musical infrastructures
    [self musInfrastructureSetup];
    
    // Initialize opencv variables
    thresh = 100;
    max_thresh = 255;
    contourmin = 100;
    max_contourmin = 2000;
    
    widthRatio = 1;
    heightRatio = 1;
    distRatio = 1;
    
    // Initialize drawing variables
    brush = 2;
    [self.view addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(refreshImage)]];
}

- (void) musInfrastructureSetup {
    if (_VI == nil) {
        _VI = [[VirtualInstrument alloc] init];
        [_VI setInstrument:@"Piano" withInstrumentID:Piano];
    }
    
    if (_Dict == nil) {
        _Dict = [[NoteNumDict alloc] init];
    }
    
    if (_AST == nil) {
        _AST = [[AssignmentTable alloc] init];
    }
    
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
    
    int contourminScaled = contourmin*distRatio*distRatio; // scaled by the distRatio^2, so that this area is correspond to the real image
    mycontours.clear();
    for( int i = 0; i< contours.size(); i++) {
        double area = contourArea(contours[i]);
        if (area > contourminScaled)
            mycontours.push_back(contours[i]);
    }
    
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
    
#ifdef HULL
    for( size_t i = 0; i< myhulls.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        cv::drawContours( drawing, myhulls, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
    
    for( size_t i = 0; i< myhulls.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255)  );
        cv::drawContours( drawing, myhulls, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
#else
    for( size_t i = 0; i< mycontours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255) );
        cv::drawContours( drawing, mycontours, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
    
    for( size_t i = 0; i< mycontours.size(); i++ )
    {
        cv::Scalar color = cv::Scalar( rng.uniform(0, 255), rng.uniform(0,255), rng.uniform(0,255)  );
        cv::drawContours( drawing, mycontours, (int)i, color, 2, 8, vector<cv::Vec4i>(), 0, cv::Point() );
    }
#endif
    
    
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
    srcMat = [self cvMatFromUIImage:SrcImg];
    cv::Mat src_gray;
    cv::Mat mix;
    
    cv::cvtColor( srcMat, src_gray, cv::COLOR_BGR2GRAY );
    cv::blur( src_gray, src_gray, cv::Size(3,3) );
    [self doContourOperationTarget:src_gray Src:srcMat Mix:mix];
    return [self UIImageFromCVMat:mix];
}

// FIXME: Apply an intelligent algorithm to map the regions to notes
// The algorithm:
static int context2noteNum (int x, int y, float dist, int hullNum) {
    return 80;
}

- (void) checkInsidePosX:(int)x Y:(int)y {
    bool isInside = false;
    float dist;
    int hullNum;
    
    // The pass in x and y are the x,y value  to the screen space, we transform it to the image space
    int scaleX, scaleY;
    scaleX = x*widthRatio;
    scaleY = y*heightRatio;
    
    // The default MIDI number
    int noteNum = 80;
    
    // RGB value
    int Red, Green, Blue;
    if (srcMat.rows > 0) {
        Red = srcMat.at<cv::Vec3b>(scaleX, scaleY)[2];
        Green = srcMat.at<cv::Vec3b>(scaleX, scaleY)[1];
        Blue = srcMat.at<cv::Vec3b>(scaleX, scaleY)[0];
        cout << "RGB = " << Red << "," << Green << "," << Blue << "\n";
    }
    
    //  Calculate the distance and scale it down the dist to the screen space
    for (int i = 0; i < myhulls.size(); i++) {
        dist = (float)cv::pointPolygonTest( myhulls[i], cv::Point2f(scaleX,scaleY), true );
        if(dist > 0) {
            dist /= distRatio;
            cout << "The current pos is in Hull " << i << " with distance " << dist << "\n";
            isInside = true;
            hullNum = i;
        }
    }
    if (!isInside) {
        cout << "The current pos is outside the contour" << "\n";
        hullNum = 0;
    }
    cout << "current pos x = " << x << " y = " << y  << "\n";
    
    // Pass the context into the algorithm, where x, y, dist are all scaled to the screen space
    noteNum = context2noteNum(x, y, dist, hullNum);
    
    MIDINote *Note = [[MIDINote alloc] initWithNote:noteNum duration:1 channel:Piano velocity:100 SysEx:0 Root:kMIDINoteOn];
    [_VI playMIDI:Note];
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    lastPoint = [touch locationInView:self.view];
    [self checkInsidePosX:lastPoint.x Y:lastPoint.y];
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {

}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

- (void) refreshImage {
    path = [UIBezierPath bezierPath];
    self.mainImage.image = nil;
    //[self startMediaBrowserFromViewController:self usingDelegate:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
