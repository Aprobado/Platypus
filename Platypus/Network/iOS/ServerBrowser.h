//
//  ServerBrowser.h
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ServerBrowserDelegate.h"

@interface ServerBrowser : NSObject<NSNetServiceBrowserDelegate> {
    NSMutableArray* servers;
    id<ServerBrowserDelegate> delegate;
}

@property(nonatomic,readonly) NSMutableArray* servers;
@property(nonatomic, retain) id<ServerBrowserDelegate> delegate;

// Start browsing for Bonjour services
- (BOOL)startBrowsingForServicesOfType:(NSString *)type InDomain:(NSString *)domain;

// Stop everything
- (void)stop;

@end
