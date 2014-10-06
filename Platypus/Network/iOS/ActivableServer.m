//
//  ActivableServer.m
//  Platypus2
//
//  Created by Raphael on 21.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "ActivableServer.h"

@implementation ActivableServer

@synthesize service, serviceName, active;

// Backup solution. Use initWithNetService if you can.
- (instancetype)initWithName:(NSString *)name {
    serviceName = name;
    active = NO;
    
    return self;
}

- (instancetype)initWithNetService:(NSNetService *)netService {
    service = netService;
    serviceName = netService.name;
    active = NO;
    
    return self;
}

- (void)activate {
    active = YES;
}

- (void)deactivate {
    active = NO;
}

@end
