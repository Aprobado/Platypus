//
//  Targets.m
//  PlatypusNetwork
//
//  Created by Raphael on 04.09.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "Targets.h"
#import "NetServiceTarget.h"
#import "HostTarget.h"

@interface Targets()

@property NSArray *allowedTargets;      // array of allowed names (white list)
@property NSArray *presentNetServices;  // retain the last server browser update

@end


@implementation Targets

@synthesize netServiceTargets, hostTargets;
@synthesize allowedTargets, presentNetServices;

- (instancetype)init {
    self = [super init];
    
    netServiceTargets = [[NSMutableArray alloc] init];
    hostTargets = [[NSMutableArray alloc] init];
    
    // get allowed targets from the preferences
    [self loadRecordedConnections];
    
    return self;
}

#pragma mark *** GENERAL METHODS ***

- (BOOL)isTargetAllowed:(NSString *)targetName {
    if (allowedTargets == nil) return NO;
    
    for (NSString *target in allowedTargets) {
        if ([targetName isEqualToString:target]) {
            // target found in allowed targets
            return YES;
        }
    }
    // target not found
    return NO;
}

- (void)loadRecordedConnections {
    allowedTargets = [[NSUserDefaults standardUserDefaults] arrayForKey:@"allowedTargets"];
    [self loadRecordedNetServices];
    [self loadRecordedHosts];
}

- (void)saveAllowedTargetsNames {
    NSMutableArray *allowedTargetsToSave = [[NSMutableArray alloc] init];
    NSArray *allTargets = @[netServiceTargets, hostTargets];
    
    for (NSMutableArray *targets in allTargets) {
        for (Target *target in targets) {
            if (target.active){
                //NSString *deviceName = [target.name substringFromIndex:8];
                [allowedTargetsToSave addObject:target.name];
            }
        }
    }
    // record the allowed devices in preferences
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:allowedTargetsToSave forKey:@"allowedTargets"];
    [userDefaults synchronize];
}

- (void)targetStateChangedAtIndex:(NSInteger)index WithValue:(BOOL)value {
    // update the target's state
    NSArray *devices = [self getDevices];
    Target *target = (Target *)[devices objectAtIndex:index];
    target.active = value;
    
    [self removeAbsentUnauthorizedNetServices]; // clean the interface
    
    // save the changes in the preferences
    [self saveAllowedTargetsNames]; // general
    [self saveAllowedNetServices];  // netServices
    [self saveAllowedHosts];        // Hosts
}

#pragma mark *** SETTER METHODS ***

#pragma mark * Set NSNetService targets

- (void)saveAllowedNetServices {
    NSMutableArray *savedNetServices = [[NSMutableArray alloc] init];
    for (NetServiceTarget *target in netServiceTargets) {
        if (target.active) {
            [savedNetServices addObject:[NSDictionary dictionaryWithObjectsAndKeys:target.name, @"targetName", target.netService.domain, @"domain", target.netService.type, @"type", target.netService.name, @"serviceName", nil]];
        }
    }
    // record the allowed netservices in preferences
    NSLog(@"saving netServices: %@", savedNetServices);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:savedNetServices forKey:@"savedNetServices"];
    [userDefaults synchronize];
}

- (void)loadRecordedNetServices {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *savedNetServices = [userDefaults arrayForKey:@"savedNetServices"];
    NSLog(@"loading netServices: %@", savedNetServices);
    for (NSDictionary *dico in savedNetServices) {
        NSString *targetName = [dico valueForKey:@"targetName"];
        
        NSString *domain = [dico objectForKey:@"domain"];
        NSString *type = [dico objectForKey:@"type"];
        NSString *serviceName = [dico valueForKey:@"serviceName"];
        
        NSNetService *service = [[NSNetService alloc] initWithDomain:domain type:type name:serviceName];
        
        NetServiceTarget *target = [[NetServiceTarget alloc] init];
        target.name = targetName;
        target.active = YES;
        target.netService = service;
        
        [netServiceTargets addObject:target];
    }
}

- (BOOL)targetServiceIsPresent:(NetServiceTarget *)target {
    for (NSNetService *service in presentNetServices) {
        if ([target.netService.name isEqualToString:service.name]) return YES;
    }
    return NO;
}

- (void)removeAbsentUnauthorizedNetServices {
    NSArray *tmp = [netServiceTargets copy];
    for (NetServiceTarget *target in tmp) {
        if (!target.active && ![self targetServiceIsPresent:target]) {
            [netServiceTargets removeObject:target];
        }
    }
}

- (BOOL)netServiceTargetAlreadyExists:(NSString *)serviceName {
    for (NetServiceTarget *target in netServiceTargets) {
        if ([target.name isEqualToString:serviceName]) return YES;
    }
    return NO;
}

- (void)updateNetServiceTargetsWithArray:(NSArray *)netServices {
    presentNetServices = netServices;
    
    // refresh the allowed list
    allowedTargets = [[NSUserDefaults standardUserDefaults] arrayForKey:@"allowedTargets"];
    [self removeAbsentUnauthorizedNetServices];
    
    for (NSNetService *service in presentNetServices) {
        // name without the 8 first UUID characters and the underscore
        NSString *serviceName = [[service name] substringFromIndex:9];
        
        if (![self netServiceTargetAlreadyExists:serviceName]) {
            // NSLog(@"%@ service does not already exist", serviceName);
            NetServiceTarget *target = [[NetServiceTarget alloc] init];
            target.name = serviceName;
            target.netService = service;
            
            if ([self isTargetAllowed:serviceName]) {
                // add the service activated
                target.active = YES;
            } else {
                // add the service deactivated
                target.active = NO;
            }
            [netServiceTargets addObject:target];
        }
    }
}

#pragma mark * Set Host targets

- (void)saveAllowedHosts {
    NSMutableArray *savedHosts = [[NSMutableArray alloc] init];
    for (HostTarget *target in hostTargets) {
        if (target.active) {
            NSDictionary *dico = [NSDictionary dictionaryWithObjectsAndKeys:target.name, @"name", target.host, @"host", [NSNumber numberWithInt:target.port], @"port", nil];
            //NSLog(@"saving host target with dict: %@", dico);
            [savedHosts addObject:dico];
        }
    }
    // record the allowed netservices in preferences
    NSLog(@"saving hosts: %@", savedHosts);
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:savedHosts forKey:@"savedHosts"];
    [userDefaults synchronize];
}

- (void)loadRecordedHosts {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *savedHosts = [userDefaults arrayForKey:@"savedHosts"];
    NSLog(@"loading hosts: %@", savedHosts);
    for (NSDictionary *dico in savedHosts) {
        NSString *name = [dico valueForKey:@"name"];
        
        NSString *host = [dico objectForKey:@"host"];
        NSNumber *port = [dico objectForKey:@"port"];
        UInt16 _port = [port intValue];
        
        [self addHostTargetWithName:name Address:host AndPort:_port Activated:YES];
    }
}

- (void)addHostTargetWithName:(NSString *)name Address:(NSString *)address AndPort:(UInt16)port Activated:(BOOL)active {
    HostTarget *target = [[HostTarget alloc] init];
    target.name = name;
    target.active = active;
    target.host = address;
    target.port = port;
    [hostTargets addObject:target];
}

#pragma mark *** GETTER METHODS ***

- (NSArray *)getDevices {
    // adding the hostTargets to netServicesTargets permits to make them appear together
    // in the interface. Only one place for all devices.
    return [netServiceTargets arrayByAddingObjectsFromArray:hostTargets];
}

- (id)getDeviceAtIndex:(NSInteger)_index {
    NSInteger index = _index;
    if (index < [netServiceTargets count]) {
        return [netServiceTargets objectAtIndex:index];
    } else {
        index -= [netServiceTargets count];
        if (index < [hostTargets count]) {
            return [hostTargets objectAtIndex:index];
        }
    }
    return nil;
}

- (NSMutableArray *)getActiveDevices {
    NSMutableArray *activeDevices = [[NSMutableArray alloc] init];
    for (NetServiceTarget *target in netServiceTargets) {
        if (target.active) {
            [activeDevices addObject:target];
        }
    }
    for (HostTarget *target in hostTargets) {
        if (target.active) {
            [activeDevices addObject:target];
        }
    }
    return activeDevices;
}

- (NSInteger)deviceCount {
    return ([netServiceTargets count] + [hostTargets count]);
}

@end
