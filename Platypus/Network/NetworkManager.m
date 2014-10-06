//
//  NetworkManager.m
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "NetworkManager.h"
#import "ServerBrowser.h"
#import "Connection.h"
#import "FileManager.h"
#import "Target.h"
#import "NetServiceTarget.h"
#import "HostTarget.h"

@interface NetworkManager ()

@property ServerBrowser *serverBrowser;
@property NSMutableArray *connections;

@end

@implementation NetworkManager

@synthesize delegate;
@synthesize serverBrowser, connections, serversView;

- (instancetype)initWithDelegate:(id)_delegate {
    delegate = _delegate;
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(AppDidBecomeActive)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(AppWillResignActive)
                                                name:UIApplicationWillResignActiveNotification
                                              object:nil];
    
    connections = [[NSMutableArray alloc] init];
    
    // setup the server browser
    serverBrowser = [[ServerBrowser alloc] init];
    serverBrowser.delegate = self;
    
    // init the servers table view
    serversView = [[ServersTableViewController alloc] initWithNibName:@"ServersTableViewController" bundle:nil];
    serversView.delegate = self;
    [serversView initProperties];
    
    if ([serversView serverCount] > 0) {
        [delegate showAuthorIcon];
    }
    
    // erase temporary files from temporary folder
    // it's here to do it only once at app startup
    [FileManager eraseAllFilesInDirectory:NSTemporaryDirectory()];
    
    return self;
}

// _connections is an array of Targets
- (void)createNeededConnections:(NSMutableArray *)_connections {
    // check the enabled connections, create the ones that are missing and delete the unused ones
    NSLog(@"create connections for : %@", _connections);
    
    for (id target in _connections) {
        if ([target class] == [NetServiceTarget class]) {
            NetServiceTarget *netServiceTarget = (NetServiceTarget *)target;
            if (![self isNetServiceConnectionAlreadyOpen:netServiceTarget.netService]) {
                Connection *connection = [[Connection alloc] init];
                [connection initConnectionWithComputer:netServiceTarget.netService];
                connection.delegate = self;
                [connections addObject:connection];
            }
        } else if ([target class] == [HostTarget class]) {
            HostTarget *hostTarget = (HostTarget *)target;
            if (![self isHostConnectionAlreadyOpen:hostTarget.host]) {
                // NSLog(@"create host connection for host %@ and port %hu", hostTarget.host, hostTarget.port);
                Connection *connection = [[Connection alloc] init];
                [connection initConnectionWithHost:hostTarget.host AndPort:hostTarget.port];
                connection.delegate = self;
                [connections addObject:connection];
            }
        }
    }
    
    NSArray *tmpCopy = [connections copy];
    for (Connection *connection in tmpCopy) {
        if (![self isConnectionStillAllowed:connection inArray:_connections]) {
            [connection stop:@"service not allowed anymore"];
            [connections removeObject:connection];
        }
    }
}
- (BOOL)isNetServiceConnectionAlreadyOpen:(NSNetService *)netService {
    for (Connection *connection in connections) {
        if (connection.netService == nil) continue;
        if ([connection.netService.name isEqualToString:netService.name]) return YES;
    }
    return NO;
}
- (BOOL)isHostConnectionAlreadyOpen:(NSString *)host {
    for (Connection *connection in connections) {
        if (connection.host == nil) continue;
        if ([connection.host isEqualToString:host]) return YES;
    }
    return NO;
}
- (BOOL)isConnectionStillAllowed:(Connection *)connection inArray:(NSMutableArray *)_connections {
    if (connection.netService != nil) {     // if it's a netService connection
        for (id target in _connections) {
            if ([target class] == [NetServiceTarget class]) {
                NetServiceTarget *netServiceTarget = (NetServiceTarget *)target;
                if ([connection.netService.name isEqualToString:netServiceTarget.netService.name]) return YES;
            }
        }
    }
    if (connection.host != nil) {           // if it's a host connection
        for (id target in _connections) {
            if ([target class] == [HostTarget class]) {
                HostTarget *hostTarget = (HostTarget *)target;
                if ([connection.host isEqualToString:hostTarget.host]) return YES;
            }
        }
    }
    return NO;
}

#pragma mark ConnectionDelegate methods implementation

- (void)bookUpdateEnded:(NSString *)bookHtmlIndex {
    [delegate bookUpdateEnded:bookHtmlIndex];
}

#pragma mark ServerBrowserDelegate methods implementation

// deprecated: we're not accepting connections from the serverbrowser anymore...
- (void)connectionAcceptedWith:(NSNetService *)netService {
    NSLog(@"Connection accepted for service: %@", [netService name]);
    //netService.delegate = self;
    //[netService resolveWithTimeout:5.0];
    
    // here alloc a new Connection and start networking with allowed computer
    
    //[self startNetworkingWithComputer:[netService name]];
}

// when serverBrowser has a change in the array of detected services
- (void)updateServerList {
    // send the detected servers upwards (ViewController) via serverBrowser
    //[delegate serverListUpdated:serverBrowser.servers];
    //NSLog(@"[NetworkManager updateServerList]");
    [serversView updatePresentServicesWithNetServices:serverBrowser.servers];
    if ([serversView serverCount] > 0) {
        [delegate showAuthorIcon];
    } else {
        [delegate hideAuthorIcon];
    }
}

/*
- (void)netServiceDidResolveAddress:(NSNetService *)netsender {
    NSLog(@"service addresses: %@", [netsender addresses]);
}*/

#pragma mark ServersTableViewController implementations

- (void)backTapped {
    [delegate backTapped];
    if ([serversView serverCount] > 0) [delegate showAuthorIcon];
    else [delegate hideAuthorIcon];
}

// the serversView filters the existing services (on / off) in "self.(void)updateServerList"
// and tells the network manager to create connections for the allowed services
- (void)activeServersUpdated {
    [self createNeededConnections:[serversView getAllowedServices]];
    if ([serversView serverCount] > 0) {
        [delegate showAuthorIcon];
    } else {
        [delegate hideAuthorIcon];
    }
}

#pragma mark UIApplicationDelegate implementations

- (void)AppWillResignActive {
    NSLog(@"app will resign active");
    
    // stop all the opened connections.
    Connection *connection;
    for (connection in connections) {
        [connection stop:@"App is entering background."];
    }
}

- (void)AppDidBecomeActive {
    // FIXME: when the app becomes active:
    // - we must check if there are allowed services recorded. the Connection objects should still exist...
    // - and create connections for them
    Connection *connection;
    for (connection in connections) {
        // NSLog(@"[NetworkManager] ask for a restart of connections now");
        [connection restart];
    }
    
    // look for an elligible service everytime the app becomes active
    // if we didn't already accepted a connection with a computer
    
    // resume the server browsing
    if (![serverBrowser startBrowsingForServicesOfType:@"_PlatypusAuthor._tcp." InDomain:@"local."]) {
        NSLog(@"Browsing for service failed...");
    }
}

@end
