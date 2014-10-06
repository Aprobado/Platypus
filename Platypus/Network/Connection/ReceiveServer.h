//
//  ReceiveServer.h
//  PlatypusNetwork
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <UIKit/UIKit.h>  
#import <Foundation/Foundation.h>
#import "ReceiveServerDelegate.h"

@interface ReceiveServer : NSObject {
    id<ReceiveServerDelegate> delegate;
}

extern UInt16 const magicNumberReceive;

- (void)startServerWithType:(NSString *)type AndName:(NSString *)name;
- (void)stopServer:(NSString *)reason;
- (void)resumePublishingService;

@property (nonatomic, strong, readwrite) NSNetService *     netService;
@property(nonatomic, retain) id<ReceiveServerDelegate> delegate;

@end
