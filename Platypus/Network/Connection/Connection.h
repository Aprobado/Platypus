//
//  Connection.h
//  Platypus2
//
//  Created by Raphael on 25.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ConnectionDelegate.h"
#import "ReceiveServerDelegate.h"

@interface Connection : NSObject<ReceiveServerDelegate> {
    id<ConnectionDelegate> delegate;
}

- (void)initConnectionWithComputer:(NSNetService *)_netService;
- (void)initConnectionWithComputerName:(NSString *)_computerName;
- (void)initConnectionWithHost:(NSString *)host AndPort:(UInt16)port;
- (void)restart;
- (void)stop:(NSString *)reason;

@property(nonatomic, retain) id<ConnectionDelegate> delegate;
@property BOOL connectionIsOn;

@property NSNetService *netService;
@property NSString *host;
@property UInt16 port;
@property NSString *computerName;

@end
