//
//  SenderDelegate.h
//  PlatypusNetwork
//
//  Created by Raphael on 24.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SenderDelegate

- (void)sendDidStopWithStatus:(NSString *)statusString;

@end