//
//  ActivableServer.h
//  Platypus2
//
//  Created by Raphael on 21.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

// A class that wraps a netService with a name
// and an on/off state
@interface ActivableServer : NSObject

- (instancetype)initWithName:(NSString *)_name;
- (instancetype)initWithNetService:(NSNetService *)netService;

- (void)activate;
- (void)deactivate;

@property NSNetService *service;
@property NSString *serviceName;
@property BOOL active;

@end
