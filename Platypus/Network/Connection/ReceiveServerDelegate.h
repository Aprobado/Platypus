//
//  ReceiveServerDelegate.h
//  Platypus2
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ReceiveServerDelegate

- (void)serverDidStartOnPort:(NSInteger)port;
- (void)receivedDataAtPath:(NSString*)path;
- (void)receivedData:(NSData*)data;

@end