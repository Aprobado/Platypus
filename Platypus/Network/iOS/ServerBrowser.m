//
//  ServerBrowser.m
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "ServerBrowser.h"

@interface ServerBrowser ()

@property NSNetServiceBrowser *browser;
@property NSNetService *allowedService;

@end

@implementation ServerBrowser

@synthesize delegate;
@synthesize browser, servers, allowedService;

- (id)init {
    servers = [[NSMutableArray alloc] init];
    return self;
}

- (BOOL)startBrowsingForServicesOfType:(NSString *)type InDomain:(NSString *)domain {
    // Restarting?
    if ( browser != nil ) {
        [self stop];
        [servers removeAllObjects];
    }
    
    browser = [[NSNetServiceBrowser alloc] init];
    if( !browser ) {
        return NO;
    }
    
    browser.delegate = self;
    [browser searchForServicesOfType:type inDomain:domain];
    NSLog(@"browser started for type %@ in domain %@", type, domain);
    
    return YES;
}

- (void)stop {
    if ( browser == nil ) {
        return;
    }
    
    [browser stop];
    browser = nil;
}

- (void)inviteToJoinServer {
    if ([servers count] <= 0) return;
    
    // get first server and remove it from list
    allowedService = [servers objectAtIndex:0];
    [servers removeObjectAtIndex:0];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Platypus Author service found" message:[NSString stringWithFormat:@"Do you want to connect to %@", [allowedService name]] delegate:self cancelButtonTitle:@"No thanks..." otherButtonTitles:@"Yes, please!", nil];
    
    [alert show];
}

- (void)serversFound {
    
}

#pragma mark * NSNetServiceBrowserDelegate Method Implementations

// New service was found
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser
           didFindService:(NSNetService *)netService
               moreComing:(BOOL)moreServicesComing {
    
    NSLog(@"found a service: %@", netService.name);
    // Make sure that we don't have such service already (why would this happen? not sure)
    if ( ! [servers containsObject:netService] ) {
        // Add it to our list
        [servers addObject:netService];
    }
    
    // id it was the last service found
    if (!moreServicesComing) {
        //[self stop];
        //[self inviteToJoinServer];
        [delegate updateServerList];
    }
}

// Service was removed
- (void)netServiceBrowser:(NSNetServiceBrowser *)netServiceBrowser didRemoveService:(NSNetService *)netService moreComing:(BOOL)moreServicesComing {
    // Remove from list
    [servers removeObject:netService];
    
    // If more entries are coming, no need to update UI just yet
    if ( moreServicesComing ) {
        return;
    }
    
    [delegate updateServerList];
}

#pragma mark * UIAlertViewDelegate implementation

- (void)alertView:(UIAlertView *)alertView
clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        // clean server list
        [servers removeAllObjects];
        // send the allowed service to the delegate
        [delegate connectionAcceptedWith:allowedService];
    } else {
        if ([servers count] > 0) {
            // propose the next server if there's one
            [self inviteToJoinServer];
        }
    }
}

@end
