//
//  HostTarget.h
//  PlatypusNetwork
//
//  Created by Raphael on 04.09.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "Target.h"

@interface HostTarget : Target

@property NSString *host;
@property UInt16 port;

- (BOOL)isValid;

@end
