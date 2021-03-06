//
//  HierarchicalScale.m
//  ArmKeyBoard
//
//  Created by tangkk on 8/12/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "HierarchicalScale.h"

#import "Definition.h"
@interface HierarchicalScale ()

@property (readonly, nonatomic) NSArray *Lydian;
@property (readonly, nonatomic) NSArray *Ionian;
@property (readonly, nonatomic) NSArray *Mixolydian;
@property (readonly, nonatomic) NSArray *Dorian;
@property (readonly, nonatomic) NSArray *Aeolian;
@property (readonly, nonatomic) NSArray *Phrygian;
@property (readonly, nonatomic) NSArray *Locrian;
@property (readonly, nonatomic) NSArray *Lydianb7;
@property (readonly, nonatomic) NSArray *Altered;
@property (readonly, nonatomic) NSArray *SymDim;
@property (readonly, nonatomic) NSArray *MelMinor;

@property (readonly, nonatomic) NSArray *LydianSeq;
@property (readonly, nonatomic) NSArray *IonianSeq;
@property (readonly, nonatomic) NSArray *MixolydianSeq;
@property (readonly, nonatomic) NSArray *DorianSeq;
@property (readonly, nonatomic) NSArray *AeolianSeq;
@property (readonly, nonatomic) NSArray *PhrygianSeq;
@property (readonly, nonatomic) NSArray *LocrianSeq;
@property (readonly, nonatomic) NSArray *Lydianb7Seq;
@property (readonly, nonatomic) NSArray *AlteredSeq;
@property (readonly, nonatomic) NSArray *SymDimSeq;
@property (readonly, nonatomic) NSArray *MelMinorSeq;

//@property (readonly, nonatomic) NSArray *LydianLinear;
//@property (readonly, nonatomic) NSArray *IonianLinear;
//@property (readonly, nonatomic) NSArray *MixolydianLinear;
//@property (readonly, nonatomic) NSArray *DorianLinear;
//@property (readonly, nonatomic) NSArray *AeolianLinear;
//@property (readonly, nonatomic) NSArray *PhrygianLinear;
//@property (readonly, nonatomic) NSArray *LocrianLinear;
//@property (readonly, nonatomic) NSArray *Lydianb7Linear;
//@property (readonly, nonatomic) NSArray *AlteredLinear;
//@property (readonly, nonatomic) NSArray *SymDimLinear;
//@property (readonly, nonatomic) NSArray *MelMinorLinear;

@end

@implementation HierarchicalScale

NSDictionary *midi2notename;

/******note degree to midi note degree******
 1 -> 0
 b2 -> 1
 2 -> 2
 b3 -> 3
 3 -> 4
 4 -> 5
 #4 (b5)-> 6
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


- (id) init {
    self = [super init];
    if (self) {
        midi2notename = @{
                          @0: @"1",
                          @1: @"b2",
                          @2: @"2",
                          @3: @"b3",
                          @4: @"3",
                          @5: @"4",
                          @6: @"#4",
                          @7: @"5",
                          @8: @"b6",
                          @9: @"6",
                          @10: @"b7",
                          @11: @"7",
                          @12: @"1*",
                          @13: @"b2*",
                          @14: @"2*",
                          @15: @"b3*",
                          @16: @"3*",
                          @17: @"4*",
                          @18: @"#4*",
                          @19: @"5*",
                          @20: @"b6*",
                          @21: @"6*",
                          @22: @"b7*",
                          @23: @"7*",
                          @24: @"1**"
                          };
        
        
        DSLog(@"****************Hierarchical Scale****************");
        /****** Lydian scale hierarchy ******
         L1:  1  5   3   7
         L2:  2   #4   6
        ****************************************/
        _Lydian = @[@[@0, @7, @4, @11, @12, @19, @16, @23, @24],@[@2, @6, @9, @14, @18, @21]];
        //_LydianSeq = @[@0, @7, @4, @11, @12, @19, @16, @23, @24, @2, @6, @9, @14, @18, @21];
        _LydianSeq = @[@0, @7, @4, @11,
                       @12, @19, @16, @23,
                       @(12+12), @(19+12), @(16+12), @(23+12),
                       @2, @6, @9,
                       @14, @18, @21,
                       @(14+12), @(18+12), @(21 + 12)
                       ];
        [self printScale:_Lydian withName:@"_Lydian"];
        
        /****** Ionian scale hierarchy ******
         L1:  1  5   3   7
         L2:  2  6
         L3: 4
         ****************************************/
        _Ionian = @[@[@0, @7, @4, @11, @12, @19, @16, @23, @24],@[@2, @9, @14, @21], @[@5, @17]];
        //_IonianSeq = @[@0, @7, @4, @11, @12, @19, @16, @23, @24,@2, @9, @14, @21, @5, @17];
        _IonianSeq = @[@0, @7, @4, @11,
                       @12, @19, @16, @23,
                       @(12+12), @(19+12), @(16+12), @(23+12),
                       @2, @9,
                       @14, @21,
                       @(14+12), @(21+12),
                       @5,
                       @17,
                       @(17+12)];
        [self printScale:_Ionian withName:@"_Ionian"];
        
        /****** Mixolydian scale hierarchy ******
         L1:  1  5   3   b7
         L2:  2  6
         L3: 4
         ****************************************/
        _Mixolydian = @[@[@0, @7, @4, @10, @12, @19, @16, @22, @24],@[@2, @9, @14, @21], @[@5, @17]];
        //_MixolydianSeq = @[@0, @7, @4, @10, @12, @19, @16, @22, @24,@2, @9, @14, @21, @5, @17];
        _MixolydianSeq = @[@0, @7, @4, @10,
                           @12, @19, @16, @22,
                           @(12+12), @(19+12), @(16+12), @(22 + 12),
                           @2, @9,
                           @14, @21,
                           @(14+12), @(21+12),
                           @5,
                           @17,
                           @(17+12)];
        [self printScale:_Mixolydian withName:@"_Mixolydian"];
        
        /****** Dorian scale hierarchy ******
         L1:  1  5   b3   b7
         L2:  2  6
         L3: 4
         ****************************************/
        _Dorian = @[@[@0, @7, @3, @10, @12, @19, @15, @22, @24],@[@2, @9, @14, @21], @[@5, @17]];
        //_DorianSeq = @[@0, @7, @3, @10, @12, @19, @15, @22, @24,@2, @9, @14, @21, @5, @17];
        _DorianSeq = @[@0, @7, @3, @10,
                       @12, @19, @15, @22,
                       @(12+12), @(19+12), @(15+12), @(22+12),
                       @2, @9,
                       @14, @21,
                       @(14+12), @(21+12),
                       @5,
                       @17,
                       @(17+12)];
        [self printScale:_Dorian withName:@"_Dorian"];
        
        /****** Aeolian scale hierarchy ******
         L1:  1  5   b3   b7
         L2:  2  4
         L3: b6
         ****************************************/
        _Aeolian= @[@[@0, @7, @3, @10, @12, @19, @15, @22, @24],@[@2, @5, @14, @17], @[@8, @20]];
        //_AeolianSeq= @[@0, @7, @3, @10, @12, @19, @15, @22, @24,@2, @5, @14, @17, @8, @20];
        _AeolianSeq= @[@0, @7, @3, @10,
                       @12, @19, @15, @22,
                       @(12+12), @(19+12), @(15+12), @(22+12),
                       @2, @5,
                       @14, @17,
                       @(14+12), @(17+12),
                       @8,
                       @20,
                       @(20+12)];
        [self printScale:_Aeolian withName:@"_Aeolian"];
        
        /****** Phrygian scale hierarchy ******
         L1:  1  5   b3   b7
         L2:  4
         L3: b2 b6
         ****************************************/
        _Phrygian= @[@[@0, @7, @3, @10, @12, @19, @15, @22, @24],@[@5, @17], @[@1, @8, @13, @20]];
        //_PhrygianSeq= @[@0, @7, @3, @10, @12, @19, @15, @22, @24,@5, @17, @1, @8, @13, @20];
        _PhrygianSeq= @[@0, @7, @3, @10,
                        @12, @19, @15, @22,
                        @(12+12), @(19+12), @(15+12), @(22+12),
                        @5,
                        @17,
                        @(17+12),
                        @1, @8,
                        @13, @20,
                        @(13+12), @(20+12)];
        [self printScale:_Phrygian withName:@"_Phrygian"];
        
        /****** Locrian scale hierarchy ******
         L1:  1  b5   b3   b7
         L2:  4  b6
         L3: b2
         ****************************************/
        _Locrian= @[@[@0, @6, @3, @10, @12, @18, @15, @22, @24],@[@5, @8, @17, @20], @[@1, @13]];
        //_LocrianSeq= @[@0, @6, @3, @10, @12, @18, @15, @22, @24,@5, @8, @17, @20, @1, @13];
        _LocrianSeq= @[@0, @6, @3, @10,
                       @12, @18, @15, @22,
                       @(12+12), @(18+12), @(15+12), @(22+12),
                       @5, @8,
                       @17, @20,
                       @(17+12), @(20+12),
                       @1,
                       @13,
                       @(13+12)];
        [self printScale:_Locrian withName:@"_Locrian"];
        
        /****** Lydian flat 7 scale hierarchy ******
         L1:  1  5   3   b7
         L2:  2   #4   6
         ****************************************/
        _Lydianb7 = @[@[@0, @7, @4, @10, @12, @19, @16, @22, @24],@[@2, @6, @9, @14, @18, @21]];
        //_Lydianb7Seq = @[@0, @7, @4, @10, @12, @19, @16, @22, @24,@2, @6, @9, @14, @18, @21];
        _Lydianb7Seq = @[@0, @7, @4, @10,
                         @12, @19, @16, @22,
                         @(12+12), @(19+12), @(16+12), @(22+12),
                         @2, @6, @9,
                         @14, @18, @21,
                         @(14+12), @(18+12), @(21+12)];
        [self printScale:_Lydianb7 withName:@"_Lydianb7"];
        
        /****** Altered scale hierarchy ******
         L1:  1  3   b7
         L2:  #4  b6  b2  #2
         L3: 5
         ****************************************/
        _Altered= @[@[@0, @4, @10, @12, @16, @22, @24],@[@6, @8, @1, @3, @18, @20, @13, @15], @[@7, @19]];
        //_AlteredSeq= @[@0, @4, @10, @12, @16, @22, @24,@6, @8, @1, @3, @18, @20, @13, @15, @7, @19];
        _AlteredSeq= @[@0, @4, @10,
                       @12, @16, @22,
                       @(12+12), @(16+12), @(22+12),
                       @6, @8, @1, @3,
                       @18, @20, @13, @15,
                       @(18+12), @(20+12), @(13+12), @(15+12),
                       @7,
                       @19,
                       @(19+12)];
        [self printScale:_Altered withName:@"_Altered"];
        
        /****** SymDim scale hierarchy ******
         L1:  1  b2  #2   3  #4  5   6  b7
         ****************************************/
        _SymDim= @[@[@0, @1, @3, @4, @6, @7, @9, @10, @12, @13, @15, @16, @18, @19, @21, @22, @24]];
        //_SymDimSeq= @[@0, @1, @3, @4, @6, @7, @9, @10, @12, @13, @15, @16, @18, @19, @21, @22, @24];
        _SymDimSeq= @[@0, @1, @3, @4, @6, @7, @9, @10,
                      @12, @13, @15, @16, @18, @19, @21, @22,
                      @(12+12), @(13+12), @(15+12), @(16+12), @(18+12), @(19+12), @(21+12), @(22+12)];
        [self printScale:_SymDim withName:@"_SymDim"];
        
        /****** MelMinor scale hierarchy ******
         L1:  1  5   b3   7
         L2:  2  6  4
         ****************************************/
        _MelMinor = @[@[@0, @7, @3, @11, @12, @19, @15, @23, @24],@[@2, @9, @14, @21], @[@5, @17]];
        //_MelMinorSeq = @[@0, @7, @3, @11, @12, @19, @15, @23, @24,@2, @9, @14, @21, @5, @17];
        _MelMinorSeq = @[@0, @7, @3, @11,
                         @12, @19, @15, @23,
                         @(12+12), @(19+12), @(15+12), @(23+12),
                         @2, @9, @14,
                         @21, @5, @17,
                         @(21+12), @(5+12), @(17+12)];
        [self printScale:_MelMinor withName:@"_MelMinor"];
        
        return self;
    }
    return nil;
}

- (NSArray *)getScale:(NSString *)scaleName {
    return [scaleName isEqualToString:@"Lydian"] ? _LydianSeq :
    [scaleName isEqualToString:@"Ionian"] ? _IonianSeq :
    [scaleName isEqualToString:@"Mixolydian"] ? _MixolydianSeq :
    [scaleName isEqualToString:@"Dorian"] ? _DorianSeq :
    [scaleName isEqualToString:@"Aeolian"] ? _AeolianSeq :
    [scaleName isEqualToString:@"Phrygian"] ? _PhrygianSeq :
    [scaleName isEqualToString:@"Locrian"] ? _LocrianSeq :
    [scaleName isEqualToString:@"Lydianb7"] ? _Lydianb7Seq :
    [scaleName isEqualToString:@"Altered"] ? _AlteredSeq :
    [scaleName isEqualToString:@"SymDim"] ? _SymDimSeq :
    [scaleName isEqualToString:@"MelMinor"] ? _MelMinorSeq : 0;
}

- (void) printScale:(NSArray *) scale withName:(NSString *)name {
    for (int i = 0; i < scale.count; i++) {
        NSArray *arr = [scale objectAtIndex:i];
        for (int j = 0; j < arr.count; j++) {
            DSLog(@"%@ at %d, %d, is %@", name, i, j, [midi2notename objectForKey:[arr objectAtIndex:j]]);
        }
    }
}

@end
