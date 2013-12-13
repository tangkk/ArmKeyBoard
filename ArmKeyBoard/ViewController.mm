//
//  ViewController.mm
//  ArmKeyBoard
//
//  Created by tangkk on 26/10/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "ViewController.h"

// FIXME: can't build under 64 bit x86_64 architecture because opencv library is not built against this.
// (Opencv2.framework doesn't seem to be supporting iPhone5s(64-bit architecture yet) according to:
// http://code.opencv.org/projects/opencv/wiki/ChangeLog

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

// Import Hierarchical Scale
#import "HierarchicalScale.h"

//#define CANNY
//#define HULL
//#define TEST

using namespace std;

@interface ViewController () {
    // Drawing Elements
    UIBezierPath *path;
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
    vector<int> contourmark; // This is to mark the original contour number to the mycontour number
    double outerarea; // The imagesize excluding all the counted contour areas
    vector<cv::Vec4i> hierarchy;
    map<int, vector<int> > region2scale;
    cv::Mat srcMat;
    bool playEnable;
    
    // Image : Screen Ratio
    float widthRatio;
    float heightRatio;
    float distRatio;
    double imagesize, screensize;
    double RPN15, RPN17; // region per note for 15 note scale or 17 note scale
    
    int currentCSTag;
    int currentCSIdx;
    pair<NSString *, NSString *> currentCS;
    NSString *currentOctave;
    vector<pair<NSString *, NSString *> > chordScaleSpace;
    vector<pair<int, int> > chordScaleIntSpace;
    vector<NSString *> octaves;
    vector<int> octavesInt;
    int totalCS;
}

@property (strong, nonatomic) IBOutlet UIImageView *mainImage;
@property (strong, nonatomic) IBOutlet UIButton *chooseImage;
@property (strong, nonatomic) IBOutletCollection(UIButton) NSArray *csButtonGrid;
@property (strong, nonatomic) UIImage *buttonClickedImg;
@property (strong, nonatomic) UIImage *buttonUnClickedImg;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeLeft;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeRight;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeDown;
@property (strong, nonatomic) UISwipeGestureRecognizer *swipeUp;
@property (strong, nonatomic) UITapGestureRecognizer *tap;
@property (strong, nonatomic) UITapGestureRecognizer *doubletap;
@property (strong, nonatomic) UITapGestureRecognizer *tripletap;
@property (strong, nonatomic) UITapGestureRecognizer *quadrupletap;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPress;

@property (strong, nonatomic) IBOutlet UIPickerView *Picker;
@property (strong, nonatomic) NSArray *chordRootArray;
@property (strong, nonatomic) NSArray *scaleArray;
@property (strong, nonatomic) NSArray *octaveArray;
@property (strong, nonatomic) IBOutlet UILabel *csLabel;
@property (strong, nonatomic) IBOutlet UIButton *quit;

/* Virtual Instrument */
@property (readonly) VirtualInstrument *VI;
@property (readonly) NoteNumDict *Dict;

/* Hierarchical Scale */
@property (readonly) HierarchicalScale *HS;

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
    
    playEnable = NO;
    
    // Initialize drawing variables
    brush = 2;
    
    // Initialize view elements
    _longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(refreshImage)];
    _swipeLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    _swipeRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    _swipeDown = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    _swipeUp = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swipeRecognized:)];
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    _doubletap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    _tripletap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    _quadrupletap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapRecognized:)];
    [_longPress setMinimumPressDuration:2];
    [_swipeLeft setDirection:UISwipeGestureRecognizerDirectionLeft];
    [_swipeRight setDirection:UISwipeGestureRecognizerDirectionRight];
    [_swipeDown setDirection:UISwipeGestureRecognizerDirectionDown];
    [_swipeUp setDirection:UISwipeGestureRecognizerDirectionUp];
    [_doubletap setNumberOfTouchesRequired:2];
    [_tripletap setNumberOfTouchesRequired:3];
    [_quadrupletap setNumberOfTouchesRequired:4];
    [self.view addGestureRecognizer:_swipeLeft];
    [self.view addGestureRecognizer:_swipeRight];
    [self.view addGestureRecognizer:_swipeDown];
    [self.view addGestureRecognizer:_swipeUp];
    [self.view addGestureRecognizer:_tap];
    [self.view addGestureRecognizer:_doubletap];
    [self.view addGestureRecognizer:_tripletap];
    [self.view addGestureRecognizer:_quadrupletap];
    [self.view addGestureRecognizer:_longPress];
    
    _chordRootArray = [[NSArray alloc] initWithObjects:@"None", @"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B", nil];
    _scaleArray = [[NSArray alloc] initWithObjects:@"None", @"Lydian", @"Ionian", @"Mixolydian", @"Dorian", @"Aeolian", @"Phrygian", @"Locrian", @"Lydianb7", @"Altered", @"SymDim", @"MelMinor", nil];
    _octaveArray = [[NSArray alloc] initWithObjects:@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    _buttonClickedImg = [UIImage imageNamed:@"Chord-Scale-white"];
    _buttonUnClickedImg = [UIImage imageNamed:@"Chord-Scale"];
    currentCSTag = 0;
    currentCSIdx = 0;
    totalCS = 0;
    pair<NSString *, NSString *> none;
    pair<int, int> noneInt;
    none = make_pair(@"None", @"None");
    noneInt = make_pair(0, 0);
    currentCS = none;
    currentOctave = @"4";
    for (int i = 0; i < _csButtonGrid.count; i++) {
        chordScaleSpace.push_back(none);
        chordScaleIntSpace.push_back(noneInt);
        octaves.push_back(@"4"); // octave 4 is the default
        octavesInt.push_back(4);
    }
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
}

- (void) viewWillAppear:(BOOL)animated {
    [_Picker selectRow:0 inComponent:0 animated:YES ];
    [_Picker selectRow:4 inComponent:1 animated:YES];
    [_Picker selectRow:0 inComponent:2 animated:YES ];
}

- (void) musInfrastructureSetup {
    if (_VI == nil) {
        _VI = [[VirtualInstrument alloc] init];
        [_VI setInstrument:@"Piano" withInstrumentID:Piano];
    }
    
    if (_Dict == nil) {
        _Dict = [[NoteNumDict alloc] init];
    }
    
    if (_HS == nil) {
        _HS = [[HierarchicalScale alloc] init];
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

// When delete a node, use the node's parent as the parent of its children, and it's children the children of its parent, modify the siblings.
//                  [0      , 1            , 2               , 3         ]
// structure: [Next, Previous, First_Child, Parent]
static void deleteHierachyNode( vector<cv::Vec4i> &hier, int nodeNum) {
    cout << hier[nodeNum] << "\n";
    int next = hier[nodeNum][0];
    int prev = hier[nodeNum][1];
    int firstChild = hier[nodeNum][2];
    int parent = hier[nodeNum][3];
    
    // set parents
    int currentChild = firstChild;
    int lastChild = firstChild;
    while (currentChild != -1) {
        hier[currentChild][3] = parent;
        lastChild = currentChild;
        currentChild = hier[currentChild][0]; // move to next
    }
    
    if (firstChild != -1) {
        if (prev == -1 && parent != -1) {
            // it's the first siblings
            hier[parent][2] = firstChild;
        }
        if (prev != -1) {
            // it's not the first siblings
            hier[prev][0] = firstChild;
            hier[firstChild][1] = prev;
        }
        if (next != -1) {
            // it's not the last siblings
            hier[lastChild][0] = next;
            hier[next][1] = lastChild;
        }
    } else {
        if (prev == -1 && parent != -1) {
            // it's the first siblings
            hier[parent][2] = next;
        }
        if (prev != -1) {
            // it's not the first siblings
            hier[prev][0] = next;
        }
        if (next != -1) {
            // it's not the last siblings
            hier[next][1] = prev;
        }
    }
    
    hier[nodeNum][0] = -2;
    hier[nodeNum][1] = -2;
    hier[nodeNum][2] = -2;
    hier[nodeNum][3] = -2;
}

// Compare the second element of the input vectors. It's to be used by the sort function.
static bool vectorCompare (vector<int>A, vector<int> B) {
    //cout << "A[1] = " << A[1] << "," << "B[1] = " << B[1] << "\n";
    return A[1] > B[1];
}

// Once we got the hierarchy, we need to calculate the score of each note based on 1. degree; 2. area; 3. central location
// Calculate and then sort. The sorted order is descending.
- (void) sortContours: (vector<vector<cv::Point> > &)conts withMarks: (vector<int> &) marks{
    // create a 2d vector - [contour index, overall score]
    vector<vector<int> > score;
    CGPoint center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    
    cout << "sortContours...\n";
    for (int i = 0; i < conts.size() - 1; i++) { // The last contour is a null for outercontour
        vector<cv::Point> cont = conts[i];
        int nodeNum = marks[i];
        cout << "******contour number****** ----> " << nodeNum << "\n";
        
        // Calculate the degree score = # of parent node + child nodes
        int degreescore = 0;
        if (hierarchy[nodeNum][3] != -1) {
            degreescore ++;
        }
        int currentChild = hierarchy[nodeNum][2];
        while (currentChild != -1) {
            degreescore ++;
            currentChild = hierarchy[currentChild][0];
        }
        // 500 is a weight for the degree score
        // It's subjected to be fixed since the absolute number of degree is much smaller than the area
        degreescore *= 500;
        
        // Calculate the area of the contour
        double areascore = contourArea(cont) / (distRatio * distRatio);
        
        // Calculate the mass center of the contour
        double locationscore;
        cv::Moments mu = moments(cont, false);
        CGPoint mc = CGPointMake((mu.m10 / mu.m00) / widthRatio, (mu.m01 / mu.m00) / heightRatio);
        float dist = sqrt((mc.x - center.x)*(mc.x - center.x) + (mc.y - center.y)*(mc.y - center.y));
        locationscore = dist;
        
        cout << "center point --> " << center.x << "," << center.y << "\n";
        cout << "mc point --> " << mc.x << "," << mc.y << "\n";
        cout << "degreescore = " << degreescore << "\n";
        cout << "areascore = " << areascore << "\n";
        cout << "locationscore = " << locationscore << "\n";
        
        int overallscore = degreescore + areascore + locationscore;
        // indScore -- [contour index, overallscore]
        vector<int> indscore;
        indscore.push_back(i);
        indscore.push_back(overallscore);
        score.push_back(indscore);
    }
    
    // Deal with the outer contour, whose is marked by -1, with only the area score and whose underlying contour is a fake one.
    vector<int> outerscore;
    int outerareascore = outerarea /(distRatio * distRatio);
    outerscore.push_back((int)conts.size() - 1);
    outerscore.push_back(outerareascore);
    score.push_back(outerscore);
    
    cout << "******original score vectors****** \n";
    for (vector<vector<int> >::iterator i = score.begin(), e = score.end(); i != e; ++i) {
        cout << (*i)[0] << "," << (*i)[1] << "\n";
    }
    
    sort(score.begin(), score.end(), vectorCompare);
    
    cout << "******sorted score vectors****** \n";
    for (vector<vector<int> >::iterator i = score.begin(), e = score.end(); i != e; ++i) {
        cout << (*i)[0] << "," << (*i)[1] << "\n";
    }
    
    // rearrange the mycontours and contourmark according to the sorted list
    // copy, clear and put back
    vector<vector<cv::Point> > mycontourcopy = conts;
    vector<int> contourmarkcopy = marks;
    conts.clear();
    marks.clear();
    for (vector<vector<int> >::iterator i = score.begin(), e = score.end(); i != e; ++i) {
        conts.push_back(mycontourcopy[(*i)[0]]);
        marks.push_back(contourmarkcopy[(*i)[0]]);
    }
    
}

-(void) doContourOperationTarget: (cv::Mat &)targtImg  Src:(cv::Mat &)srcImg Mix:(cv::Mat &)mixImg{
    cv::Mat threshold_output;
    cv::Mat canny_output;
    vector<vector<cv::Point> > contours;
    vector<cv::Point> outercontour;
    thresh = 100;
    
    contours.clear();
    outercontour.clear();
    hierarchy.clear();
        
#ifdef CANNY
    cv::Canny( targtImg, canny_output, thresh, thresh*2, 3 );
    findContours( canny_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
#else
    cv::threshold( targtImg, threshold_output, thresh, 255, cv::THRESH_BINARY );
    findContours( threshold_output, contours, hierarchy, cv::RETR_TREE, cv::CHAIN_APPROX_SIMPLE, cv::Point(0, 0) );
#endif

#pragma mark - delete some small contours and the corresponding hierarchy nodes.
    /******Print out the hierarchy******/
    cout << "******Hierarchy******\n";
    for (vector<cv::Vec4i>::iterator ih = hierarchy.begin(), eh = hierarchy.end(); ih != eh ; ++ih ) {
        cout << *ih << "\n";
    }
    
    int contourminScaled = contourmin*distRatio*distRatio; // scaled by the distRatio^2, so that this area is correspond to the real image
    mycontours.clear();
    contourmark.clear();
    outerarea = imagesize;
    cout << "******Nodes to be deleted" << "\n";
    for( int i = 0; i< contours.size(); i++) {
        double area = contourArea(contours[i]);
        if (area > contourminScaled) {
            mycontours.push_back(contours[i]);
            contourmark.push_back(i);
            outerarea -= area;
            outercontour = contours[i]; // This is a fake contour
        }
        else {
            deleteHierachyNode(hierarchy, i);
        }
    }
    
#pragma mark - outer contours
    if (mycontours.size()) {
        mycontours.push_back(outercontour);
        contourmark.push_back(-1);
        cout << "******outerArea******\n" << outerarea << "\n";
    } else {
        // create an outer contour (the whole screen) when no contour is detected
        cout << "******create outer contour******\n" ;
        vector<cv::Point> contour;
        cv::Point P0(0, 0);
        cv::Point P1(_mainImage.image.size.width, 0);
        cv::Point P2(_mainImage.image.size.width, _mainImage.image.size.height);
        cv::Point P3(0, _mainImage.image.size.height);
        contour.push_back(P0);
        contour.push_back(P1);
        contour.push_back(P2);
        contour.push_back(P3);
        mycontours.push_back(contour);
        contourmark.push_back(-1);
    }
    
    /******Print out the new hierarchy******/
    cout << "******New Hierarchy******\n";
    for (vector<cv::Vec4i>::iterator ih = hierarchy.begin(), eh = hierarchy.end(); ih != eh ; ++ih ) {
        cout << *ih << "\n";
    }
    
#pragma mark - sort contours
    cout << "******original contourmark****** \n";
    for (vector<int>::iterator i = contourmark.begin(), e = contourmark.end(); i != e; ++i) {
        cout << (*i) << "\n";
    }
    
    if (mycontours.size()) {
        [self sortContours:mycontours withMarks:contourmark];
    }
    
    cout << "******sorted contourmark****** \n";
    for (vector<int>::iterator i = contourmark.begin(), e = contourmark.end(); i != e; ++i) {
        cout << (*i) << "\n";
    }
    
#pragma mark - draw contours
    cv::RNG rng(12345);
    cv::Mat drawing;
#ifdef CANNY
    drawing = cv::Mat::zeros( canny_output.size(), CV_8UC4 );
#else
    drawing = cv::Mat::zeros( threshold_output.size(), CV_8UC4 );
#endif
    
#ifdef HULL
    /*************************Find the convex hull object for each contour********************************/
    myhulls.clear();
    vector<vector<cv::Point> >hull( mycontours.size());
    for( size_t i = 0; i < mycontours.size(); i++ ) {
        cv::convexHull( cv::Mat(mycontours[i]), hull[i], false );
        myhulls.push_back(hull[i]);
    }
    
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
    playEnable = YES;
    [_chooseImage setHidden:YES];
    for (int i = 0 ; i < _csButtonGrid.count; i++) {
        UIButton *button = [_csButtonGrid objectAtIndex:i];
        [button setHidden:YES];
    }
    [_Picker setHidden:YES];
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
    
    // Calculate the total chord-scales (only consecutive chord-scale in the space count)
    totalCS = 0;
    for (int i = 0; i < chordScaleIntSpace.size(); i++) {
        if (chordScaleIntSpace[i].first && chordScaleIntSpace[i].second) {
            totalCS++;
        } else {
            break;
        }
    }
    NSLog(@"totalCS: %d", totalCS);
    
    [self startMediaBrowserFromViewController:self usingDelegate:self];
}

// Delegate method for the pick controller media browser
- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSLog(@"imagePickerController called!");
    
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    UIImage *selectedImage;
    
    // Handle the original image only
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerOriginalImage];
        // Set the display content mode
        _mainImage.contentMode = UIViewContentModeScaleAspectFit;
        //_mainImage.contentMode = UIViewContentModeScaleAspectFill;
        
        imagesize = selectedImage.size.width * selectedImage.size.height;
        screensize = self.view.frame.size.width * self.view.frame.size.height;
        RPN15 = imagesize / 15;
        RPN17 = imagesize / 17;
        cout << "image size x = " << selectedImage.size.width << " y= " << selectedImage.size.height << "size = " << imagesize << "\n";
        cout << "screen size x = " << self.view.frame.size.width << " y=" << self.view.frame.size.height << "size = " << screensize <<"\n";
        widthRatio = selectedImage.size.width / self.view.frame.size.width;
        heightRatio = selectedImage.size.height / self.view.frame.size.height;
        distRatio = sqrt(widthRatio*widthRatio + heightRatio*heightRatio);
        cout << "widthRatio = " << widthRatio  << "\n";
        cout << "heightRatio = " << heightRatio << "\n";
        cout << "distRatio = " << distRatio << "\n";
        
        // Do Image processing using opencv here;
        _mainImage.image = [self ConvexHullProcessSrcImage:selectedImage];
        [self.view bringSubviewToFront:_mainImage];
        
        // Perform the algorithm on to the contours to produce the region-scale mapping
        [self region2hs:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
    }
    
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    NSLog(@"imagePickerControllerDidCancel called!");
    [self refreshImage];
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

// Apply an intelligent algorithm to 1. map the regions to notes; 2. fine elaborate the very note details according to the very tapping context
/* Note that this is not a "problem statement" in mathematical sense
 Problem statement 1: Given a set of regions of pixels that together form a large rectangular image,
 find out an optimal scheme to map a certain musical scale(in the form of pitch class) into these pixel regions so that
 within this scale a non-musical player can improvise along a corresponding chord moment musically.
 (Notes in different range can be swapped via certain mechanisms)
 Problem statement 2: Given a region containing several notes, and a tapping position,
 together with the pixel's RGB value, determine which note to be selected and the velocity of this note,
 such that a non-musical player can improvise along a corresponding chord moment musically.
*/
/* Key observation:
 1. Every scale has a tonic note, which the underlining chord moment put stress on
 2. Every other notes has some kind of "degree" related to the tonic note, and "functionality" and "importance"  to each other
 3. Assume every chord moment is of equal importance, such that playing each scale is indepent of the last scale
 4. The regions together actually forms a graph, and the notes in the scale can also form a graph
 5. The scale can be Octatonic, Heptatonic, Hexatonic, Pentatonic... etc.
 6. It's a non-linear note arrangment compared with the tranditional instrument's linear note arrangement
 7. The scale is chord-scale, and the important notes within it are the chord notes, and the important sequence is arpeggio
 8. velocity can be associated with RGB or distance to the contour
 9. The root of a spanning tree of a graph can be associated with the most connected region in the image
 10. The root of a spanning tree of a graph can also be associated with the largest region in the image
 */
/* The algorithm:
 */
/* Evaluation:
 use WIJAM as a platform, auto master config, play a couple of songs with this keyboard and with the old one,
 record them and let real people to evaluate the musicality of the songs
 */
- (void) region2hs:(NSString *) scaleName withTonic:(NSString *)tonic withOctave:(NSString *)oct{
    // Note that when this function is called the mycontours and contourmark are already sorted in descending order. The outer contour is also included.
    int mapstart = 0;
    float accum = 0;
    region2scale.clear();
    NSString *compRoot = [[NSString alloc] initWithFormat:@"%@%@", tonic, oct];
    NSLog(@"compRoot is %@", compRoot);
    int root = [[_Dict.Dict objectForKey:compRoot] intValue];
    
    NSString *label = [[NSString alloc] initWithFormat:@"%@%@", compRoot, scaleName];
    [_csLabel setText:label];
    [_csLabel setHidden:NO];
    [self.view bringSubviewToFront:_csLabel];
    
    [UIView animateWithDuration:1 animations:^{_csLabel.alpha = 0.5;}];
    [UIView animateWithDuration:1 animations:^{_csLabel.alpha = 0.0;}];
    
    for (int i = 0; i < mycontours.size(); i++) {
        vector<cv::Point> contour = mycontours[i];
        double contourarea;
        if (contourmark[i] == -1) {
            contourarea = outerarea;
        } else {
            contourarea = contourArea(contour);
        }
        
        float ratio;
        if ([scaleName isEqualToString:@"Altered"] || [scaleName isEqualToString:@"SymDim"]) {
            ratio = contourarea / RPN17;
        } else {
            ratio = contourarea / RPN15;
        }
        
        int contmark = contourmark[i];
        NSLog(@"contmark: %d", contmark);
        NSLog(@"ratio = %f", ratio);
        
        NSArray *scale = [_HS getScale:scaleName];
        if (ratio >= 1) {
            // map notes to regions
            int number = floor(ratio);
            vector<int> notes;
            for (int j = mapstart; j < MIN(mapstart + number, scale.count); j++) {
                notes.push_back([[scale objectAtIndex:j] intValue] + root);
            }
            // Finally we insert an entry to the map
            region2scale[contmark] = notes;
            mapstart += number;
        } else {
            // map regions to notes
            vector<int> notes;
            notes.push_back([[scale objectAtIndex:MIN(mapstart, scale.count - 1)] intValue] + root);
            region2scale[contmark] = notes;
            accum += ratio;
            if (accum >= 1) {
                accum = 0;
                mapstart++;
                if (mapstart >= scale.count) {
                    mapstart = (int) scale.count - 1;
                }
            }
        }
    }
    
    // print out the regsion2scale map
    for (map<int, vector<int> >::iterator I = region2scale.begin(), E = region2scale.end(); I != E; ++I) {
        int key = (*I).first;
        vector<int> value = (*I).second;
        NSLog(@"key = %d", key);
        cout << "Value = ";
        for (vector<int>::iterator IV = value.begin(), EV = value.end(); IV != EV; ++IV) {
            cout << (*IV) << ",";
        }
        cout << "\n";
    }
}

static int context2noteNum (int x, int y, float dist, int contourNum, int R, int G, int B, vector<int> &noteset) {
    int numberofNotes = (int) noteset.size();
    // Make sure every note within this region get chance to show up
    // A simple but workable approach:
    int noteIdx = ((x + y) % 10 + (R + G + B)) % numberofNotes;
    
    return noteset[noteIdx];
}

- (void) playAtPosX:(int)x Y:(int)y {
    bool isInside = false;
    float dist;
    int contourNum;
    
    // The pass in x and y are the x,y value  to the screen space, we transform it to the image space
    int scaleX, scaleY;
    scaleX = x*widthRatio;
    scaleY = y*heightRatio;
    
    // The default MIDI number
    int noteNum = 80;
    
    // RGB value
    int Red = 0, Green = 0, Blue = 0;
    if (srcMat.rows > 0) {
        Red = srcMat.at<cv::Vec4b>(scaleX, scaleY)[0];
        Green = srcMat.at<cv::Vec4b>(scaleX, scaleY)[1];
        Blue = srcMat.at<cv::Vec4b>(scaleX, scaleY)[2];
        cout << "RGB = " << Red << "," << Green << "," << Blue << "\n";
    }
    
    //  Calculate the distance and scale it down the dist to the screen space, take the innermost contour's noteset.
    for (int i = 0; i < mycontours.size(); i++) {
        dist = (float)cv::pointPolygonTest( mycontours[i], cv::Point2f(scaleX,scaleY), true );
        if(dist > 0) {
            dist /= distRatio;
            cout << "The current pos is in contour " << contourmark[i] << " with distance " << dist << "\n";
            isInside = true;
            contourNum = contourmark[i];
        }
    }
    if (!isInside) {
        cout << "The current pos is in contour -1" << "\n";
        contourNum = -1;
    }
    cout << "current pos x = " << x << " y = " << y  << " , " << "contourNum = " << contourNum << "\n";
    vector <int> noteset = region2scale[contourNum];
    
    // Pass the context into the algorithm, where x, y, dist are all scaled to the screen space, and generate a note
    if (noteset.size() > 0) {
        cout << "there's a note ! \n";
        noteNum = context2noteNum(x, y, dist, contourNum, Red, Green, Blue, noteset);
    }
    
    MIDINote *Note = [[MIDINote alloc] initWithNote:noteNum duration:1 channel:Piano velocity:100 SysEx:0 Root:kMIDINoteOn];
    [_VI playMIDI:Note];
}

# pragma mark - refresh image
// FIXME: when longPressed, don't perform this right away, show a button and let the user choose instead.
- (void) refreshImage {
    NSLog(@"longPressed");
    [self.view bringSubviewToFront:_quit];
    [_quit setHidden:NO];
    //_quit.alpha = 0;
    [UIView animateWithDuration:1 animations:^{_quit.alpha = 1;}];
}

- (IBAction)quit:(id)sender {
    path = [UIBezierPath bezierPath];
    self.mainImage.image = nil;
    playEnable = NO;
    [_chooseImage setHidden:NO];
    for (int i = 0 ; i < _csButtonGrid.count; i++) {
        UIButton *button = [_csButtonGrid objectAtIndex:i];
        [button setHidden:NO];
    }
    [_Picker setHidden:NO];
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
    currentCS = chordScaleSpace[0];
    currentOctave = octaves[0];
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/******chord-scale zone ******/
#pragma mark - chord-scale zone
- (IBAction)buttonClicker:(id)sender {
    UIButton *button = (UIButton *)sender;
    currentCSTag = (int) button.tag;
    
    [_Picker selectRow:chordScaleIntSpace[currentCSTag].first inComponent:0 animated:YES ];
    [_Picker selectRow:octavesInt[currentCSTag] inComponent:1 animated:YES];
    [_Picker selectRow:chordScaleIntSpace[currentCSTag].second inComponent:2 animated:YES ];
    
}

/****** Required by Pickerview controller ******/
// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 3;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (component == 0) {
        return [_chordRootArray count];
    } else if (component == 1) {
        return [_octaveArray count];
    } else {
        return [_scaleArray count];
    }
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    if (component == 0) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, pickerView.frame.size.width, 20)];
        label.backgroundColor = [UIColor blackColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont fontWithName:@"Courier-Bold" size:16];
        label.text = [NSString stringWithFormat:@" %@", [_chordRootArray objectAtIndex:row]];
        return label;
    } else if (component == 1) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, pickerView.frame.size.width, 20)];
        label.backgroundColor = [UIColor blackColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont fontWithName:@"Courier-Bold" size:16];
        label.text = [NSString stringWithFormat:@" %@", [_octaveArray objectAtIndex:row]];
        return label;
    }  else {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, pickerView.frame.size.width, 20)];
        label.backgroundColor = [UIColor blackColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont fontWithName:@"Courier-Bold" size:16];
        label.text = [NSString stringWithFormat:@" %@", [_scaleArray objectAtIndex:row]];
        return label;
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    // Set the chord-scale of the one chord-scale note via this
    
    if (component == 0) {
        chordScaleSpace[currentCSTag].first =  [_chordRootArray objectAtIndex:row];
        chordScaleIntSpace[currentCSTag].first = (int)row;
    } else if (component == 1) {
        octaves[currentCSTag] = [_octaveArray objectAtIndex:row];
        octavesInt[currentCSTag] = (int)row;
    } else {
        chordScaleSpace[currentCSTag].second = [_scaleArray objectAtIndex:row];
        chordScaleIntSpace[currentCSTag].second = (int)row;
    }
    
    if (chordScaleIntSpace[currentCSTag].first == 0 || chordScaleIntSpace[currentCSTag].second == 0) {
        UIButton *button = (UIButton *)[_csButtonGrid objectAtIndex:currentCSTag];
        [button setBackgroundImage:_buttonUnClickedImg forState:UIControlStateNormal];
    } else {
        UIButton *button = (UIButton *)[_csButtonGrid objectAtIndex:currentCSTag];
        [button setBackgroundImage:_buttonClickedImg forState:UIControlStateNormal];
    }
    
    currentCS = chordScaleSpace[0];
    currentOctave = octaves[0];
}

#pragma mark - gestures
- (void)tapRecognized:(UITapGestureRecognizer *) sender {
    [UIView animateWithDuration:0.5 animations:^{_quit.alpha = 0;}];
    if (sender.numberOfTouchesRequired == 1) {
        CGPoint lastPoint = [sender locationInView:self.view];
        if (playEnable) {
            [self playAtPosX:lastPoint.x Y:lastPoint.y];
        }
    } else if (sender.numberOfTouchesRequired == 2) {
        CGPoint lastPointFirst = [sender locationOfTouch:0 inView:self.view];
        CGPoint lastPointSecond = [sender locationOfTouch:1 inView:self.view];
        if (playEnable) {
            [self playAtPosX:lastPointFirst.x Y:lastPointFirst.y];
            [self playAtPosX:lastPointSecond.x Y:lastPointSecond.y];
        }
    } else if (sender.numberOfTouchesRequired == 3) {
        CGPoint lastPointFirst = [sender locationOfTouch:0 inView:self.view];
        CGPoint lastPointSecond = [sender locationOfTouch:1 inView:self.view];
        CGPoint lastPointThird = [sender locationOfTouch:2 inView:self.view];
        if (playEnable) {
            [self playAtPosX:lastPointFirst.x Y:lastPointFirst.y];
            [self playAtPosX:lastPointSecond.x Y:lastPointSecond.y];
            [self playAtPosX:lastPointThird.x Y:lastPointThird.y];
        }
    } else if (sender.numberOfTouchesRequired == 4) {
        CGPoint lastPointFirst = [sender locationOfTouch:0 inView:self.view];
        CGPoint lastPointSecond = [sender locationOfTouch:1 inView:self.view];
        CGPoint lastPointThird = [sender locationOfTouch:2 inView:self.view];
        CGPoint lastPointFourth = [sender locationOfTouch:3 inView:self.view];
        if (playEnable) {
            [self playAtPosX:lastPointFirst.x Y:lastPointFirst.y];
            [self playAtPosX:lastPointSecond.x Y:lastPointSecond.y];
            [self playAtPosX:lastPointThird.x Y:lastPointThird.y];
            [self playAtPosX:lastPointFourth.x Y:lastPointFourth.y];
        }
    }
    
}

/****** swipe gestures for switching between chord-scales******/
- (void)swipeRecognized:(UISwipeGestureRecognizer *)sender {
    if (playEnable && totalCS > 0) {
        if (sender.direction == UISwipeGestureRecognizerDirectionLeft) {
            if (currentCSIdx == 0) {
                currentCSIdx = totalCS - 1;
            } else {
                currentCSIdx --;
            }
            currentCS = chordScaleSpace[currentCSIdx];
            currentOctave = octaves[currentCSIdx];
            // refresh the chord-scale and the mapping
            [self region2hs:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
            NSLog(@"SwipeRecognized Left");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionRight) {
            if (currentCSIdx == totalCS - 1) {
                currentCSIdx = 0;
            } else {
                currentCSIdx++;
            }
            currentCS = chordScaleSpace[currentCSIdx];
            currentOctave = octaves[currentCSIdx];
            // refresh the chord-scale and the mapping
            [self region2hs:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
            NSLog(@"SwipeRecognized Right");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionDown) {
            NSLog(@"SwipeRecognized Down");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionUp) {
            NSLog(@"SwipeRecognized Up");
        }
        NSLog(@"currentCSIdx : %d", currentCSIdx);
    }
}


@end
