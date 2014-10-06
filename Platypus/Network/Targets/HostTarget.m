//
//  HostTarget.m
//  PlatypusNetwork
//
//  Created by Raphael on 04.09.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "HostTarget.h"

// addition to NSString
@interface NSString (usefull_stuff)
- (BOOL) isAllDigits;
@end

@implementation NSString (usefull_stuff)

- (BOOL) isAllDigits
{
    NSCharacterSet* nonNumbers = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSRange r = [self rangeOfCharacterFromSet: nonNumbers];
    return r.location == NSNotFound;
}

@end

@implementation HostTarget

@synthesize host, port;

- (BOOL)isValid {
    // we consider the address to be iPv4
    NSArray *explodedAddress = [host componentsSeparatedByString:@"."];
    if ([explodedAddress count] != 4) return NO;
    for (NSString *addressFragment in explodedAddress) {
        if (![addressFragment isAllDigits]) return NO;
        if ([addressFragment integerValue] > 255 || [addressFragment integerValue] < 0) return NO;
    }
    
    // port must be between 81 and 65535
    if (port < 81 || port > 65535) return NO;
    
    return YES;
}

@end
