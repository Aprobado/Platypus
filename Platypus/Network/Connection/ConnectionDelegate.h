//
//  ConnectionDelegate.h
//  Platypus2
//
//  Created by Raphael on 25.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol ConnectionDelegate

- (void)bookUpdateEnded:(NSString *)bookHtmlIndex;

@end