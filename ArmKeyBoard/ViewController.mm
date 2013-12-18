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

#import "Definition.h"

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

// CoreMotion headers
#import <CoreMotion/CoreMotion.h>

// Opencv configuration
//#define CANNY

// FIXME: still need to add some drawing functionalities in the future

using namespace std;

@interface ViewController () {
    int thresh ;
    int contourmin;
    double outerarea;                   // The imagesize excluding all the counted contour areas
    cv::Mat srcMat;
    vector<vector<cv::Point> > mycontours;
    vector<int> contourmark;        // This is to mark the original contour number to the mycontour number
    vector<cv::Vec4i> hierarchy;
    map<int, vector<int> > region2scale;        // This is the very map between region and scale
    
    // Image : Screen Ratio
    float widthRatio;
    float heightRatio;
    float distRatio;
    double imagesize, screensize;
    double RPN15, RPN17;                    // region per note for 15 note scale or 17 note scale
    bool isOneContour;
    
    // chord-scale things
    bool playEnable;
    int currentCSTag;
    int currentCSIdx;
    int lastCSTag;
    int totalCS;
    int currentInstIdx;
    pair<NSString *, NSString *> currentCS;
    NSString *currentOctave;
    int currentInstrument;
    vector<pair<NSString *, NSString *> > chordScaleSpace;
    vector<pair<int, int> > chordScaleIntSpace;
    vector<NSString *> octaves;
    vector<int> octavesInt;
    
    // gravity readings
    float gravityX, gravityY, gravityZ;
    bool gravityGuard;
}
/* Gesture things and views*/
@property (strong, nonatomic) IBOutlet UIImageView *mainImage;
@property (strong, nonatomic) IBOutlet UIButton *chooseImage;
@property (strong, nonatomic) IBOutlet UIButton *quit;
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

/* chord-scale things */
@property (strong, nonatomic) IBOutlet UIPickerView *csPicker;
@property (strong, nonatomic) IBOutlet UILabel *csLabel;
@property (strong, nonatomic) NSArray *chordRootArray;
@property (strong, nonatomic) NSArray *scaleArray;
@property (strong, nonatomic) NSArray *octaveArray;
@property (strong, nonatomic) NSArray *instrumentArray;

/* Virtual Instrument */
@property (readonly) VirtualInstrument *VI;
@property (readonly) NoteNumDict *dict;

/* Hierarchical Scale */
@property (readonly) HierarchicalScale *HS;

/* CoreMotion */
@property (strong, nonatomic) CMMotionManager *motionManager;
@property (strong, nonatomic) NSOperationQueue *queue;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self opencvVarInit];
    [self musInfrastructureSetup];
    [self gesturesSetup];
    [self chordScaleGridSetup];
    [self coreMotionSetup];
    
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:NO];
    [self csPickerLookInit];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - setup zone

- (void) csPickerLookInit {
    [_csPicker selectRow:0 inComponent:0 animated:YES ];
    [_csPicker selectRow:3 inComponent:1 animated:YES];
    [_csPicker selectRow:0 inComponent:2 animated:YES ];
}

- (void) opencvVarInit {
    thresh = 100;
    contourmin = 100;
    widthRatio = 1;
    heightRatio = 1;
    distRatio = 1;
    isOneContour = false;
}

- (void) gesturesSetup {
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
}

- (void) chordScaleGridSetup {
    playEnable = NO;
    _chordRootArray = [[NSArray alloc] initWithObjects:@"None", @"C", @"C#", @"D", @"D#", @"E", @"F", @"F#", @"G", @"G#", @"A", @"A#", @"B", nil];
    _scaleArray = [[NSArray alloc] initWithObjects:@"None", @"Lydian", @"Ionian", @"Mixolydian", @"Dorian", @"Aeolian", @"Phrygian",
                   @"Locrian", @"Lydianb7", @"Altered", @"SymDim", @"MelMinor", nil];
    _octaveArray = [[NSArray alloc] initWithObjects:@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7", nil];
    _instrumentArray = [[NSArray alloc] initWithObjects:@Piano, @SteelGuitar, /*@Guitar, @Trombone, */@Vibraphone, nil];
    _buttonClickedImg = [UIImage imageNamed:@"Chord-Scale-white"];
    _buttonUnClickedImg = [UIImage imageNamed:@"Chord-Scale"];
    currentCSTag = 0;
    lastCSTag = 0;
    currentCSIdx = 0;
    totalCS = 0;
    currentInstIdx = 0;
    pair<NSString *, NSString *> none;
    pair<int, int> noneInt;
    none = make_pair(@"None", @"None");
    noneInt = make_pair(0, 0);
    currentCS = none;
    currentOctave = @"3";
    currentInstrument = Piano;
    for (int i = 0; i < _csButtonGrid.count; i++) {
        chordScaleSpace.push_back(none);
        chordScaleIntSpace.push_back(noneInt);
        octaves.push_back(@"3"); // octave 3 is by default
        octavesInt.push_back(3);
    }
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
}

- (void) coreMotionSetup {
    _motionManager = [[CMMotionManager alloc] init];
    _motionManager.accelerometerUpdateInterval = 0.1;
    gravityGuard = false;
    if (_motionManager.accelerometerAvailable) {
        _queue = [NSOperationQueue currentQueue];
        [_motionManager startAccelerometerUpdatesToQueue:_queue withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            CMAcceleration acceleration = accelerometerData.acceleration;
            gravityX = acceleration.x;
            gravityY = acceleration.y;
            gravityZ = acceleration.z;
            
            // flip the page if abs x is larger than a certain number
            if (!gravityGuard) {
                if (gravityX > 0.7) {
                    if (playEnable && totalCS > 0) {
                        if (currentCSIdx == totalCS - 1) {
                            currentCSIdx = 0;
                        } else {
                            currentCSIdx++;
                        }
                        currentCS = chordScaleSpace[currentCSIdx];
                        currentOctave = octaves[currentCSIdx];
                        
                        // refresh the chord-scale and the mapping
                        [self regionToHierarchicalScale:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
                        gravityGuard = true;
                    }
                } else if (gravityX < -0.7) {
                    if (playEnable && totalCS > 0) {
                        if (currentCSIdx == 0) {
                            currentCSIdx = totalCS - 1;
                        } else {
                            currentCSIdx --;
                        }
                        currentCS = chordScaleSpace[currentCSIdx];
                        currentOctave = octaves[currentCSIdx];
                        [self regionToHierarchicalScale:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
                        gravityGuard = true;
                    }
                }
            }
            
            if (gravityX > -0.5 && gravityX < 0.5) {
                gravityGuard = false;
            }
        }];
    }
}

- (void) musInfrastructureSetup {
    if (_VI == nil) {
        _VI = [[VirtualInstrument alloc] init];
        //[_VI setInstrument:@"Trombone" withInstrumentID:Trombone];
        [_VI setInstrument:@"SteelGuitar" withInstrumentID:SteelGuitar];
        // FIXME: don't know why the "Guitar" does not work
        //[_VI setInstrument:@"Guitar" withInstrumentID:Guitar];
        [_VI setInstrument:@"Piano" withInstrumentID:Piano];
        [_VI setInstrument:@"Vibraphone" withInstrumentID:Vibraphone];
    }
    
    if (_dict == nil) {
        _dict = [[NoteNumDict alloc] init];
    }
    
    if (_HS == nil) {
        _HS = [[HierarchicalScale alloc] init];
    }
    
}

#pragma mark - opencv zone

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
    return A[1] > B[1];
}

// Once we got the hierarchy, we need to calculate the score of each note based on 1. degree; 2. area; 3. central location
// Calculate and then sort. The sorted order is descending order.
- (void) sortContours: (vector<vector<cv::Point> > &)conts withMarks: (vector<int> &) marks{
    // create a 2d vector - [contour index, overall score]
    vector<vector<int> > score;
    CGPoint center = CGPointMake(self.view.frame.size.width / 2, self.view.frame.size.height / 2);
    
    DSLog(@"sortContours...");
    for (int i = 0; i < conts.size() - 1; i++) { // The last contour is a null for outercontour
        vector<cv::Point> cont = conts[i];
        int nodeNum = marks[i];
        DSLog(@"******contour number****** ----> , %d", nodeNum);
        
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
        
        DSLog(@"center point --> , %f, %f", center.x, center.y);
        DSLog(@"mc point --> , %f, %f", mc.x, mc.y );
        DSLog(@"degreescore = %d", degreescore);
        DSLog(@"areascore = %f", areascore) ;
        DSLog(@"locationscore = %f", locationscore);
        
        int overallscore = degreescore + areascore + locationscore;
        // indScore -- [contour index, overallscore]
        vector<int> indscore;
        indscore.push_back(i);
        indscore.push_back(overallscore);
        score.push_back(indscore);
    }
    
    // deal with the outer contour, which is marked by -1, with only the area score and whose underlying contour is a fake one.
    vector<int> outerscore;
    int outerareascore = outerarea /(distRatio * distRatio);
    outerscore.push_back((int)conts.size() - 1);
    outerscore.push_back(outerareascore);
    score.push_back(outerscore);
    
    DSLog(@"******original score vectors******");
    for (vector<vector<int> >::iterator i = score.begin(), e = score.end(); i != e; ++i) {
        DSLog(@"%d, %d", (*i)[0], (*i)[1]);
    }
    
    sort(score.begin(), score.end(), vectorCompare);
    
    DSLog(@"******sorted score vectors******");
    for (vector<vector<int> >::iterator i = score.begin(), e = score.end(); i != e; ++i) {
        DSLog(@"%d, %d", (*i)[0], (*i)[1]);
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

/******The main opencv job is done here in this function******/
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

// ******delete some small contours and the corresponding hierarchy nodes.******//
    /******Print out the old hierarchy******/
    DSLog(@"******Hierarchy******") ;
#ifdef TEST
    for (vector<cv::Vec4i>::iterator ih = hierarchy.begin(), eh = hierarchy.end(); ih != eh ; ++ih ) {
        cout << *ih << "\n";
    }
#endif
    
    int contourminScaled = contourmin*distRatio*distRatio; // scaled by the distRatio^2, so that this area corresponds to the real image
    mycontours.clear();
    contourmark.clear();
    outerarea = imagesize;
    DSLog(@"******Nodes to be deleted" );
    for( int i = 0; i< contours.size(); i++) {
        double area = contourArea(contours[i]);
        if (area > contourminScaled) {
            mycontours.push_back(contours[i]);
            contourmark.push_back(i);
            outerarea -= area;
            outercontour = contours[i]; // This is a fake contour for the outer
        }
        else {
            /* This is an algorithm to delete nodes in the hierarchy */
            deleteHierachyNode(hierarchy, i);
        }
    }
    
// ******outer contours - create an outer contour (the whole screen) when no contour is detected, otherwise just use the fake one ******//
    if (mycontours.size()) {
        mycontours.push_back(outercontour);
        contourmark.push_back(-1);
    } else {
        DSLog(@"******create outer contour, and it's the only contour******");
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
        isOneContour = true;
    }
    
    /******Print out the new hierarchy******/
    DSLog(@"******New Hierarchy******");
#ifdef TEST
    for (vector<cv::Vec4i>::iterator ih = hierarchy.begin(), eh = hierarchy.end(); ih != eh ; ++ih ) {
        cout << *ih << "\n";
    }
#endif
    
// ****** sort contours ******//
    DSLog(@"******original contourmark******") ;
    for (vector<int>::iterator i = contourmark.begin(), e = contourmark.end(); i != e; ++i) {
        DSLog(@"%d", (*i));
    }
    
    if (mycontours.size()) {
        [self sortContours:mycontours withMarks:contourmark];
    }
    
    DSLog(@"******sorted contourmark******") ;
    for (vector<int>::iterator i = contourmark.begin(), e = contourmark.end(); i != e; ++i) {
        DSLog(@"%d", (*i));
    }
    
// ******draw contours ******//
    cv::RNG rng(12345);
    cv::Mat drawing;
#ifdef CANNY
    drawing = cv::Mat::zeros( canny_output.size(), CV_8UC4 );
#else
    drawing = cv::Mat::zeros( threshold_output.size(), CV_8UC4 );
#endif
    
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
    
    /*************************Mix the source and the drawings********************************/
    double alpha, beta;
    alpha = 0.5;
    beta = 1 - alpha;
    cv::addWeighted(srcImg, alpha, drawing, beta, 0, mixImg);
}

- (UIImage *) opencvImageProcessing:(UIImage *) SrcImg {
    srcMat = [self cvMatFromUIImage:SrcImg];
    cv::Mat src_gray;
    cv::Mat mix;
    
    cv::cvtColor( srcMat, src_gray, cv::COLOR_BGR2GRAY );
    cv::blur( src_gray, src_gray, cv::Size(3,3) );
    [self doContourOperationTarget:src_gray Src:srcMat Mix:mix];
    return [self UIImageFromCVMat:mix];
}

#pragma mark - photo picking zone
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
    [_chooseImage setHidden:YES];
    for (int i = 0 ; i < _csButtonGrid.count; i++) {
        UIButton *button = [_csButtonGrid objectAtIndex:i];
        [button setHidden:YES];
    }
    [_csPicker setHidden:YES];
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
    
    // Calculate the total chord-scales (only consecutive chord-scale in the space counts)
    playEnable = YES;
    totalCS = 0;
    for (int i = 0; i < chordScaleIntSpace.size(); i++) {
        if (chordScaleIntSpace[i].first && chordScaleIntSpace[i].second) {
            totalCS++;
        } else {
            break;
        }
    }
    DSLog(@"totalCS: %d", totalCS);
    
    [self startMediaBrowserFromViewController:self usingDelegate:self];
}

/****** delegate for the pick controller media browser ******/
- (void) imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    NSString *mediaType = [info objectForKey:UIImagePickerControllerMediaType];
    UIImage *selectedImage;
    
    // Handle the original image only
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo) {
        selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerOriginalImage];
        // Set the display content mode
        _mainImage.contentMode = UIViewContentModeScaleAspectFit;
        
        imagesize = selectedImage.size.width * selectedImage.size.height;
        screensize = self.view.frame.size.width * self.view.frame.size.height;
        RPN15 = imagesize / 15;
        RPN17 = imagesize / 17;
        widthRatio = selectedImage.size.width / self.view.frame.size.width;
        heightRatio = selectedImage.size.height / self.view.frame.size.height;
        distRatio = sqrt(widthRatio*widthRatio + heightRatio*heightRatio);
        DSLog(@"image size x = %f, y = %f, size = %f", selectedImage.size.width, selectedImage.size.height, imagesize);
        DSLog(@"screen size x = %f, y = %f, size = %f", self.view.frame.size.width, self.view.frame.size.height, screensize);
        DSLog(@"widthRatio = %f, heightRation = %f, distRation = %f", widthRatio, heightRatio, distRatio);
        
        // Do Image processing using opencv
        _mainImage.image = [self opencvImageProcessing:selectedImage];
        [self.view bringSubviewToFront:_mainImage];
        
        // Perform the algorithm on to the contours to produce the region-scale mapping
        [self regionToHierarchicalScale:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
    }
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self quit:_quit];
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - mapping algorithm zone

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
/* Evaluation:
 use WIJAM as a platform, auto master config, play a couple of songs with this keyboard and with the old one,
 record them and let real people to evaluate the musicality of the songs
 */
/*Note that when this function is called the mycontours and contourmark are already sorted in descending order. The outer contour is also included*/
- (void) regionToHierarchicalScale:(NSString *) scaleName withTonic:(NSString *)tonic withOctave:(NSString *)oct {
    int mapstart = 0;
    float accum = 0;
    
    NSString *compRoot = [[NSString alloc] initWithFormat:@"%@%@", tonic, oct];
    DSLog(@"compRoot is %@", compRoot);
    int root = [_dict getNumforNote:compRoot];
    
    NSString *label = [[NSString alloc] initWithFormat:@"%@ %@", compRoot, scaleName];
    [_csLabel setText:label];
    [_csLabel setHidden:NO];
    [self.view bringSubviewToFront:_csLabel];
    
    [UIView animateWithDuration:1 animations:^{_csLabel.alpha = 0.5;}];
    [UIView animateWithDuration:1 animations:^{_csLabel.alpha = 0.0;}];
    
    // FIXME: if there's only one contour, make it linear layout like the original WIJAM keyboard(because there's no need to distributed layout anymore)
    // and make also some lines to separate the keyboard. And at the same time sort the hierarchical scale also.
    region2scale.clear();
    if (isOneContour) {
        vector<int> notes;
        NSArray *scale = [_HS getScale:scaleName];
        for (int j = 0; j < scale.count; j++) {
            notes.push_back([[scale objectAtIndex:j] intValue] + root);
        }
        // sort the note set because in this case the keyboard is regressed to the simplest linear layout
        sort(notes.begin(), notes.end());
        // Finally we insert an entry to the map
        region2scale[-1] = notes;
    } else {
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
            DSLog(@"contmark: %d", contmark);
            DSLog(@"ratio = %f", ratio);
            
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
    }
#ifdef TEST
     // print out the regsion2scale map
    for (map<int, vector<int> >::iterator I = region2scale.begin(), E = region2scale.end(); I != E; ++I) {
        int key = (*I).first;
        vector<int> value = (*I).second;
        DSLog(@"key = %d", key);
        DSLog(@"Value = ");
        for (vector<int>::iterator IV = value.begin(), EV = value.end(); IV != EV; ++IV) {
            cout << (*IV) << ",";
        }
        cout << "\n";
    }
#endif
}

static int context2noteNum (int x, int y, float dist, int contourNum, int R, int G, int B, vector<int> &noteset, bool oneContour, float height) {
    int numberofNotes = (int) noteset.size();
    // Make sure every note within this region get chance to show up
    // A simple but workable approach:
    int noteIdx;
    if (oneContour) {
        // regress to the simple linear keyboard layout
        noteIdx = numberofNotes - 1 - MIN(floor((y * numberofNotes) / height), numberofNotes - 1);
    } else {
        noteIdx = ((x + y) % 10 + (R + G + B)) % numberofNotes;
    }
    return noteset[noteIdx];
}

#pragma mark - play zone

// FIXME: make some animation to give visual feedback on the multiple tapping
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
        DSLog(@"RGB = %d, %d, %d", Red , Green, Blue);
    }
    
    // FIXME: how to make good use the dist information?
    // FIXME: how to eliminate the need of the below calculation to determine in which contour the point is inside
    //  Calculate the distance and scale it down the dist to the screen space, take the innermost contour's noteset.
    for (int i = 0; i < mycontours.size(); i++) {
        dist = (float)cv::pointPolygonTest( mycontours[i], cv::Point2f(scaleX,scaleY), true );
        if(dist > 0) {
            dist /= distRatio;
            DSLog(@"The current pos is in contour  %d with distance %f", contourmark[i], dist);
            isInside = true;
            contourNum = contourmark[i];
        }
    }
    
    if (! isInside) {
        DSLog(@"The current pos is in contour -1");
        contourNum = -1;
    }
    DSLog(@"current pos x = %d, y = %d, contourNum = %d", x, y, contourNum);
    vector <int> noteset = region2scale[contourNum];
    
    // Pass the context into the algorithm, where x, y, dist are all scaled to the screen space
    if (noteset.size() > 0) {
        noteNum = context2noteNum(x, y, dist, contourNum, Red, Green, Blue, noteset, isOneContour, self.view.frame.size.height);
    }
    
    int velocity;
    if (isOneContour) {
        velocity = MIN((x * 127 / self.view.frame.size.width), 127);
    } else {
        velocity = 127 - MIN(ABS(gravityY * 127), 127);
    }
    // FIXME: The C4 note always sounds weired... don't know why (fixed, delete all the 60 related entries of the piano.aupreset)
    MIDINote *Note = [[MIDINote alloc] initWithNote:noteNum duration:1 channel:currentInstrument velocity:velocity SysEx:0 Root:kMIDINoteOn];
    [_VI playMIDI:Note];
}

# pragma mark - quit zone

- (void) refreshImage {
    [self.view bringSubviewToFront:_quit];
    [_quit setHidden:NO];
    [UIView animateWithDuration:1 animations:^{_quit.alpha = 0.5;}];
}

- (IBAction)quit:(id)sender {
    self.mainImage.image = nil;
    playEnable = NO;
    [_chooseImage setHidden:NO];
    for (int i = 0 ; i < _csButtonGrid.count; i++) {
        UIButton *button = [_csButtonGrid objectAtIndex:i];
        [button setHidden:NO];
    }
    [_csPicker setHidden:NO];
    [self csPickerLookInit];
    [_csLabel setHidden:YES];
    [_quit setHidden:YES];
    currentCS = chordScaleSpace[0];
    currentOctave = octaves[0];
    currentCSTag = 0;
    currentInstIdx = 0;
    currentInstrument = [[_instrumentArray objectAtIndex:currentInstIdx] intValue];
    lastCSTag = 0;
    currentCSIdx = 0;
    totalCS = 0;
    isOneContour = false;
}

/******chord-scale zone ******/
#pragma mark - chord-scale zone

- (IBAction)buttonClicker:(id)sender {
    UIButton *button = (UIButton *)sender;
    currentCSTag = (int) button.tag;
    
    [_csPicker selectRow:chordScaleIntSpace[currentCSTag].first inComponent:0 animated:YES ];
    [_csPicker selectRow:octavesInt[currentCSTag] inComponent:1 animated:YES];
    [_csPicker selectRow:chordScaleIntSpace[currentCSTag].second inComponent:2 animated:YES ];
    
    // set this button's appearance
    [button setBackgroundImage:_buttonClickedImg forState:UIControlStateNormal];
    button.alpha = 0.5;
    
    // reset last button's appearance
    if (currentCSTag != lastCSTag) {
        if (chordScaleIntSpace[lastCSTag].first == 0 || chordScaleIntSpace[lastCSTag].second == 0) {
            UIButton *lastbutton = (UIButton *)[_csButtonGrid objectAtIndex:lastCSTag];
            [lastbutton setBackgroundImage:_buttonUnClickedImg forState:UIControlStateNormal];
            lastbutton.alpha = 1;
        } else {
            UIButton *lastbutton = (UIButton *)[_csButtonGrid objectAtIndex:lastCSTag];
            [lastbutton setBackgroundImage:_buttonClickedImg forState:UIControlStateNormal];
            lastbutton.alpha = 1;
        }
    }
    lastCSTag = currentCSTag;
}

/****** Required by Pickerview controller ******/
// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    if (pickerView == _csPicker) {
        return 3;
    } else {
        return 1;
    }
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    if (pickerView == _csPicker) {
        if (component == 0) {
            return [_chordRootArray count];
        } else if (component == 1) {
            return [_octaveArray count];
        } else {
            return [_scaleArray count];
        }
    } else {
        return 10;
    }
}

- (UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    if (pickerView == _csPicker) {
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
    } else {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, pickerView.frame.size.width, 10)];
        label.backgroundColor = [UIColor blackColor];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [UIFont fontWithName:@"Courier-Bold" size:10];
        label.text = [NSString stringWithFormat:@" %@", [_chordRootArray objectAtIndex:row]];
        return label;
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    // Set the chord-scale of the one chord-scale note via this
    if (pickerView == _csPicker) {
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
            button.alpha = 1;
        }
        
        currentCS = chordScaleSpace[0];
        currentOctave = octaves[0];
    } else {
        /* do something if there's another picker view*/
    }

}

#pragma mark - gestures zone
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

- (void)swipeRecognized:(UISwipeGestureRecognizer *)sender {
    if (playEnable && totalCS > 0) {
        // FIXME: think of another good mechanism to switch between instruments
        if (sender.direction == UISwipeGestureRecognizerDirectionLeft) {
//            if (currentInstIdx == 0) {
//                currentInstIdx = (int)_instrumentArray.count - 1;
//            } else {
//                currentInstIdx -- ;
//            }
//            currentInstrument = [[_instrumentArray objectAtIndex:currentInstIdx] intValue];
//            
//            if (currentInstrument == SteelGuitar) {
//                [self changeOctaves:NO];
//                [self changeOctaves:NO];
//            } else if (currentInstrument == Piano) {
//                [self changeOctaves:YES];
//                [self changeOctaves:YES];
//            }
            DSLog(@"SwipeRecognized Left");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionRight) {
//            if (currentInstIdx == _instrumentArray.count - 1) {
//                currentInstIdx = 0;
//            } else {
//                currentInstIdx ++;
//            }
//            currentInstrument = [[_instrumentArray objectAtIndex:currentInstIdx] intValue];
//            
//            if (currentInstrument == SteelGuitar) {
//                [self changeOctaves:NO];
//                [self changeOctaves:NO];
//            } else if (currentInstrument == Vibraphone) {
//                [self changeOctaves:YES];
//                [self changeOctaves:YES];
//            }
            DSLog(@"SwipeRecognized Right");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionDown) {
            [self changeOctaves:NO];
            DSLog(@"SwipeRecognized Down");
        } else if (sender.direction == UISwipeGestureRecognizerDirectionUp) {
            [self changeOctaves:YES];
            DSLog(@"SwipeRecognized Up");
        }
    }
}

- (void) changeOctaves: (bool)higher {
    if (higher) {
        // raise octaves
        for (int i = 0; i < octaves.size(); i ++) {
            int oct = octavesInt[i];
            if (oct < 7) {
                oct = ++ octavesInt[i];
                octaves[i] = [_octaveArray objectAtIndex:oct];
            }
        }
    } else {
        // lower octaves
        for (int i = 0; i < octaves.size(); i ++) {
            int oct = octavesInt[i];
            if (oct > 0) {
                oct = -- octavesInt[i];
                octaves[i] = [_octaveArray objectAtIndex:oct];
            }
        }
    }
     currentOctave = octaves[currentCSIdx];
    [self regionToHierarchicalScale:currentCS.second withTonic:currentCS.first withOctave:currentOctave];
}

#pragma mark - backing zone
- (void)directoryDidChange:(DirectoryWatcher *)folderWatcher {
    
}


@end
