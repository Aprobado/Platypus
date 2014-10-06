//
//  Targets.h
//  PlatypusNetwork
//
//  Created by Raphael on 04.09.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Targets : NSObject

// GENERAL
- (void)targetStateChangedAtIndex:(NSInteger)index WithValue:(BOOL)value;

// SETTERS
- (void)updateNetServiceTargetsWithArray:(NSArray *)netServices;
- (void)addHostTargetWithName:(NSString *)name Address:(NSString *)address AndPort:(UInt16)port Activated:(BOOL)active;

// GETTERS
// includes netServices and hosts targets
- (NSArray *)getDevices;
- (id)getDeviceAtIndex:(NSInteger)index;
- (NSMutableArray *)getActiveDevices;
- (NSInteger)deviceCount;

@property NSMutableArray *netServiceTargets;
@property NSMutableArray *hostTargets;

@end
