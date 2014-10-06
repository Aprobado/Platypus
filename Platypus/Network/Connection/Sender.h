//
//  Sender.h
//  PlatypusNetwork
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SenderDelegate.h"

@interface Sender : NSObject {
    id<SenderDelegate, NSStreamDelegate> delegate;
}

extern UInt16 const magicNumberSend;

- (id)initWithNetService:(NSNetService *)service;
- (id)initWithType:(NSString *)type AndName:(NSString *)name;
- (id)initWithHost:(NSString *)_host AndPort:(UInt16)_port;

- (void)startSendData:(NSData*)data;
- (void)startSendFileAtPath:(NSString *)filePath;

- (void)stopSendWithStatus:(NSString *)statusString;

@property(nonatomic, retain) id<SenderDelegate> delegate;
@property NSNetService *    netService;
@property NSString *        host;
@property UInt16            port;

@end
