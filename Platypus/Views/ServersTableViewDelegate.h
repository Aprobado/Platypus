//
//  ServersTableViewDelegate.h
//  Platypus2
//
//  Created by Raphael on 22.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ServersTableViewDelegate

- (void)backTapped;
- (void)activeServersUpdated;

@end