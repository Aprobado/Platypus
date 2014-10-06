//
//  NetworkManagerDelegate.h
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol NetworkManagerDelegate

- (void)bookUpdateStarted;
- (void)bookUpdateEnded:(NSString *)bookHtmlIndex;

- (void)showAuthorIcon;
- (void)hideAuthorIcon;
- (void)backTapped;

@end