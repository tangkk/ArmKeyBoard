//
//  Definition.h
//  MasterMachine
//
//  Created by tangkk on 16/8/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#define AnimateArrayLength 10
#define RegLength 5
#define noteSize 15

//#define TEST

#ifdef TEST
#   define DSLog(...) NSLog(__VA_ARGS__)
#else
#   define DSLog(...)
#endif

#ifdef DEBUG
#   define NSLog(...) NSLog(__VA_ARGS__)
#else
#   define NSLog(...)
#endif
