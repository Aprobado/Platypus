//
//  ReceiveServer.m
//  PlatypusNetwork
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "ReceiveServer.h"
#import "FileManager.h"

#include <CFNetwork/CFNetwork.h>

#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

UInt16 const magicNumberReceive = 28473;

@interface ReceiveServer () <NSStreamDelegate, NSNetServiceDelegate>

// private properties

@property (nonatomic, assign)            BOOL               isStarted;
@property (nonatomic, assign, readonly ) BOOL               isReceiving;
@property (nonatomic, assign, readwrite) CFSocketRef        listeningSocket;
@property (nonatomic, strong, readwrite) NSInputStream *    networkStream;
@property (nonatomic, strong, readwrite) NSOutputStream *   fileStream;
@property (nonatomic, readwrite)         NSUInteger         totalBytesWritten;
@property (nonatomic, readwrite)         BOOL               fileVerified;
@property (nonatomic, copy,   readwrite) NSString *         filePath;

// forward declarations

- (void)stopServer:(NSString *)reason;

@end

@implementation ReceiveServer

@synthesize delegate, totalBytesWritten, fileVerified;

@synthesize netService      = _netService;
@synthesize networkStream   = _networkStream;
@synthesize listeningSocket = _listeningSocket;
@synthesize fileStream      = _fileStream;
@synthesize filePath        = _filePath;

#pragma mark * Status management

// These methods were used by the core transfer code to update the UI.
// We send delegate messages from here

- (void)serverDidStartOnPort:(NSUInteger)port
{
    assert( (port != 0) && (port < 65536) );
    if (_netService != nil) NSLog(@"[%@] Server started on port: %lu", [_netService name], (unsigned long)port);
    else NSLog(@"Manual Server started on port: %lu", (unsigned long)port);
    [delegate serverDidStartOnPort:port];
}

- (void)serverDidStopWithReason:(NSString *)reason
{
    if (reason == nil) {
        reason = @"Stopped";
    }
    if (_netService != nil) NSLog(@"[%@] Server stopped with reason: %@", [_netService name], reason);
    else NSLog(@"Manual Server stopped with reason: %@", reason);
}

- (void)receiveDidStart
{
    if (_netService != nil) NSLog(@"[%@] Server receive did start", [_netService name]);
    else NSLog(@"Manual Server receive did start");
}

- (void)updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
    // update status is spamming a lot
    // if (_netService != nil) NSLog(@"[%@] Update server status to: %@", [_netService name], statusString);
    // else NSLog(@"Update server status to: %@", statusString);
}

- (void)receiveDidStopWithStatus:(NSString *)statusString
{
    if (statusString == nil) {
        assert(self.filePath != nil);
        // we received the file correctly
        // check its checksum if we have it
        // and copy it to the correct path
        NSData* data = [NSData dataWithContentsOfFile:self.filePath];
        
        NSData* dataWithoutHeader = [data subdataWithRange:NSMakeRange(sizeof(UInt16), data.length - sizeof(UInt16))];
        
        if (_netService != nil) NSLog(@"[%@] Server receiving stopped with status: Receive succeeded", [_netService name]);
        else NSLog(@"Manual Server receiving stopped with status: Receive succeeded");
        
        [delegate receivedData:dataWithoutHeader];
    }
    else {
        if (_netService != nil) NSLog(@"[%@] Server receiving stopped with status: %@", [_netService name], statusString);
        else NSLog(@"Manual Server receiving stopped with status: %@", statusString);
    }
}


#pragma mark * Core transfer code

// This is the code that actually does the networking.

- (BOOL)isReceiving
{
    return (self.networkStream != nil);
}

- (void)startReceive:(int)fd
{
    CFReadStreamRef     readStream;
    
    assert(fd >= 0);
    
    assert(self.networkStream == nil);      // can't already be receiving
    assert(self.fileStream == nil);         // ditto
    assert(self.filePath == nil);           // ditto
    
    // Open a stream for the file we're going to receive into.
    
    self.filePath = [FileManager pathForTemporaryFileWithPrefix:@"Receive"];
    assert(self.filePath != nil);
    
    self.fileStream = [NSOutputStream outputStreamToFileAtPath:self.filePath append:NO];
    assert(self.fileStream != nil);
    
    [self.fileStream open];
    
    // Open a stream based on the existing socket file descriptor.  Then configure
    // the stream for async operation.
    
    CFStreamCreatePairWithSocket(NULL, fd, &readStream, NULL);
    assert(readStream != NULL);
    
    self.networkStream = (__bridge NSInputStream *) readStream;
    
    CFRelease(readStream);
    
    [self.networkStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    
    self.networkStream.delegate = self;
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.networkStream open];
    
    totalBytesWritten = 0;
    fileVerified = NO;
    
    // Tell the UI we're receiving.
    
    [self receiveDidStart];
}

- (void)stopReceiveWithStatus:(NSString *)statusString
{
    if (self.networkStream != nil) {
        self.networkStream.delegate = nil;
        [self.networkStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.networkStream close];
        self.networkStream = nil;
    }
    if (self.fileStream != nil) {
        [self.fileStream close];
        self.fileStream = nil;
    }
    totalBytesWritten = 0;
    fileVerified = NO;
    [self receiveDidStopWithStatus:statusString];
    self.filePath = nil;
}

- (BOOL)isPacketLegit
{
    // get the first part of the filestream
    NSRange range = NSMakeRange(0, sizeof(UInt16));
    // convert to UInt16
    NSData* data = [NSData dataWithContentsOfFile:self.filePath];
    uint16_t number;
    [data getBytes:&number range:range];
    
    // check against const magicNumberReceive
    return number == magicNumberReceive;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode
// An NSStream delegate callback that's called when events happen on our
// network stream.
{
    assert(aStream == self.networkStream);
    #pragma unused(aStream)
    
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            [self updateStatus:@"Opened connection"];
        } break;
        case NSStreamEventHasBytesAvailable: {
            NSInteger       bytesRead;
            uint8_t         buffer[32768];
            
            [self updateStatus:@"Receiving"];
            
            // Pull some data off the network.
            
            bytesRead = [self.networkStream read:buffer maxLength:sizeof(buffer)];
            if (bytesRead == -1) {
                [self stopReceiveWithStatus:@"Network read error"];
            } else if (bytesRead == 0) {
                [self stopReceiveWithStatus:nil];
            } else {
                NSInteger   bytesWritten;
                NSInteger   bytesWrittenSoFar;
                
                // Write to the file.
                
                bytesWrittenSoFar = 0;
                do {
                    bytesWritten = [self.fileStream write:&buffer[bytesWrittenSoFar] maxLength:bytesRead - bytesWrittenSoFar];
                    assert(bytesWritten != 0);
                    if (bytesWritten == -1) {
                        [self stopReceiveWithStatus:@"File write error"];
                        break;
                    } else {
                        bytesWrittenSoFar += bytesWritten;
                        
                        if (!fileVerified) {
                            totalBytesWritten += bytesWritten;
                            if (totalBytesWritten >= sizeof(UInt16)) {
                                if ([self isPacketLegit]) {
                                    fileVerified = YES;
                                } else {
                                    [self stopReceiveWithStatus:@"File can't be verified"];
                                }
                            }
                        }
                        
                    }
                } while (bytesWrittenSoFar != bytesRead);
            }
        } break;
        case NSStreamEventHasSpaceAvailable: {
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventErrorOccurred: {
            [self stopReceiveWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

- (void)acceptConnection:(int)fd
{
    int     junk;
    
    // If we already have a connection, reject this new one.  This is one of the
    // big simplifying assumptions in this code.  A real server should handle
    // multiple simultaneous connections.
    
    if ( self.isReceiving ) {
        junk = close(fd);
        assert(junk == 0);
    } else {
        [self startReceive:fd];
    }
}

static void AcceptCallback(CFSocketRef s, CFSocketCallBackType type, CFDataRef address, const void *data, void *info)
// Called by CFSocket when someone connects to our listening socket.
// This implementation just bounces the request up to Objective-C.
{
    ReceiveServer *  obj;
    
    #pragma unused(type)
    assert(type == kCFSocketAcceptCallBack);
    #pragma unused(address)
    // assert(address == NULL);
    assert(data != NULL);
    
    obj = (__bridge ReceiveServer *) info;
    assert(obj != nil);
    
    assert(s == obj->_listeningSocket);
    #pragma unused(s)
    
    [obj acceptConnection:*(int *)data];
}

- (void)netService:(NSNetService *)sender didNotPublish:(NSDictionary *)errorDict
// A NSNetService delegate callback that's called if our Bonjour registration
// fails.  We respond by shutting down the server.
//
// This is another of the big simplifying assumptions in this sample.
// A real server would use the real name of the device for registrations,
// and handle automatically renaming the service on conflicts.  A real
// client would allow the user to browse for services.  To simplify things
// we just hard-wire the service name in the client and, in the server, fail
// if there's a service name conflict.
{
#pragma unused(sender)
    assert(sender == self.netService);
#pragma unused(errorDict)
    
    [self stopServer:@"Registration failed"];
}

- (void)startServerWithType:(NSString *)type AndName:(NSString *)name
{
    BOOL                success;
    int                 err;
    int                 fd;
    int                 junk;
    struct sockaddr_in  addr;
    NSUInteger          port;
    
    // Create a listening socket and use CFSocket to integrate it into our
    // runloop.  We bind to port 0, which causes the kernel to give us
    // any free port, then use getsockname to find out what port number we
    // actually got.
    
    port = 0;
    
    fd = socket(AF_INET, SOCK_STREAM, 0);
    success = (fd != -1);
    
    if (success) {
        memset(&addr, 0, sizeof(addr));
        addr.sin_len    = sizeof(addr);
        addr.sin_family = AF_INET;
        addr.sin_port   = 0;
        addr.sin_addr.s_addr = INADDR_ANY;
        err = bind(fd, (const struct sockaddr *) &addr, sizeof(addr));
        success = (err == 0);
    }
    if (success) {
        err = listen(fd, 5);
        success = (err == 0);
    }
    if (success) {
        socklen_t   addrLen;
        
        addrLen = sizeof(addr);
        err = getsockname(fd, (struct sockaddr *) &addr, &addrLen);
        success = (err == 0);
        
        if (success) {
            assert(addrLen == sizeof(addr));
            port = ntohs(addr.sin_port);
        }
    }
    if (success) {
        CFSocketContext context = { 0, (__bridge void *) self, NULL, NULL, NULL };
        
        assert(self->_listeningSocket == NULL);
        self->_listeningSocket = CFSocketCreateWithNative(
                                                          NULL,
                                                          fd,
                                                          kCFSocketAcceptCallBack,
                                                          AcceptCallback,
                                                          &context
                                                          );
        success = (self->_listeningSocket != NULL);
        
        if (success) {
            CFRunLoopSourceRef  rls;
            
            fd = -1;        // listeningSocket is now responsible for closing fd
            
            rls = CFSocketCreateRunLoopSource(NULL, self.listeningSocket, 0);
            assert(rls != NULL);
            
            CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
            
            CFRelease(rls);
        }
    }
    
    // Now register our service with Bonjour.  See the comments in -netService:didNotPublish:
    // for more info about this simplifying assumption.
    
    if (success) {
        // if type or name is nil, don't bother publish a netService.
        if (type != nil && name != nil) {
            self.netService = [[NSNetService alloc] initWithDomain:@"local." type:type name:name port:port];
            success = (self.netService != nil);
            
            if (success) {
                self.netService.delegate = self;
                
                [self.netService publishWithOptions:NSNetServiceNoAutoRename];
                
                // continues in -netServiceDidPublish: or -netService:didNotPublish: ...
            }
        }
    }
    
    // Clean up after failure.
    
    if ( success ) {
        assert(port != 0);
        self.isStarted = YES;
        [self serverDidStartOnPort:port];
    } else {
        [self stopServer:@"Start failed"];
        if (fd != -1) {
            junk = close(fd);
            assert(junk == 0);
        }
    }
}

- (void)stopServer:(NSString *)reason
{
    if (self.isReceiving) {
        [self stopReceiveWithStatus:@"Cancelled"];
    }
    if (self.netService != nil) {
        [self.netService stop];
        self.netService = nil;
    }
    if (self.listeningSocket != NULL) {
        CFSocketInvalidate(self.listeningSocket);
        CFRelease(self->_listeningSocket);
        self->_listeningSocket = NULL;
    }
    
    self.isStarted = NO;
    [self serverDidStopWithReason:reason];
}

#pragma mark * Actions

// can be used on application did become active to keep it alive
- (void)resumePublishingService {
    if (self.netService == nil) NSLog(@"netservice is nil.. can't publish");
    else {
        NSLog(@"[%@] netservice is not nil, try to republish", [_netService name]);
        [self.netService publishWithOptions:NSNetServiceNoAutoRename];
    }
}

// TODO: have these outside of the class
/*
- (void)startOrStopAction:(id)sender
{
#pragma unused(sender)
    if (self.isStarted) {
        [self stopServer:nil];
    } else {
        [self startServer];
    }
}
*/
- (void)dealloc
{
    [self stopServer:@"deallocation"];
}


@end
