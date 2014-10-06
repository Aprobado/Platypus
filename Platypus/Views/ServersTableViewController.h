//
//  ServersTableViewController.h
//  Platypus2
//
//  Created by Raphael on 22.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ServersTableViewDelegate.h"

@interface ServersTableViewController : UITableViewController<UITextFieldDelegate> {
    id<ServersTableViewDelegate, UITextFieldDelegate> delegate;
}

@property(nonatomic, retain) id<ServersTableViewDelegate> delegate;
@property NSMutableArray *activableServers;
@property NSMutableArray *presentServices;
@property NSMutableArray *manuallyAddedServers;

- (void)initProperties;
//- (void)addAllowedNetServices:(NSArray *)netServices;
- (void)updatePresentServicesWithNetServices:(NSMutableArray *)services;
- (NSInteger)serverCount;
- (NSMutableArray *)getAllowedServices;

@end
