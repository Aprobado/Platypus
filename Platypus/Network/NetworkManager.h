//
//  NetworkManager.h
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <UIKit/UIKit.h>  
#import <Foundation/Foundation.h>

#import "NetworkManagerDelegate.h"
#import "ServerBrowserDelegate.h"
#import "Connection/ConnectionDelegate.h"
#import "ServersTableViewController.h"
#import "ServersTableViewDelegate.h"

@interface NetworkManager : NSObject<UIApplicationDelegate, ServerBrowserDelegate, ConnectionDelegate, ServersTableViewDelegate> {
    id<NetworkManagerDelegate> delegate;
}

- (instancetype)initWithDelegate:(id)_delegate;
- (void)createNeededConnections:(NSMutableArray *)connections;

@property(nonatomic, retain) id<NetworkManagerDelegate> delegate;
@property ServersTableViewController *serversView;

@end
