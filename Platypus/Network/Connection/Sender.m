//
//  Sender.m
//  PlatypusNetwork
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "Sender.h"

#import "QNetworkAdditions.h"

UInt16 const magicNumberSend = 28473;

enum {
    kSendBufferSize = 32768
};

@interface Sender () <NSStreamDelegate>

// private properties

@property (nonatomic, assign, readonly ) BOOL               isSending;
@property (nonatomic, strong, readwrite) NSOutputStream *   networkStream;
@property (nonatomic, strong, readwrite) NSInputStream *    fileStream;
@property (nonatomic, assign, readonly ) uint8_t *          buffer;
@property (nonatomic, assign, readwrite) size_t             bufferOffset;
@property (nonatomic, assign, readwrite) size_t             bufferLimit;

@end

@implementation Sender {
    uint8_t _buffer[kSendBufferSize];
}

@synthesize delegate;
@synthesize netService;
@synthesize host, port;

@synthesize networkStream = _networkStream;
@synthesize fileStream    = _fileStream;
@synthesize bufferOffset  = _bufferOffset;
@synthesize bufferLimit   = _bufferLimit;

- (id)initWithNetService:(NSNetService *)service {
    self = [super init];
    netService = service;
    return self;
}

- (id)initWithType:(NSString *)type AndName:(NSString *)name {
    NSNetService *service = [[NSNetService alloc] initWithDomain:@"local." type:type name:name];
    return [self initWithNetService:service];
}

- (id)initWithHost:(NSString *)_host AndPort:(UInt16)_port {
    host = _host;
    port = _port;
    return self;
}

#pragma mark * Status management

// These methods were used by the core transfer code to update the UI.
// We send delegate messages from here

- (void)sendDidStart
{
    if (netService != nil) {
        NSLog(@"send did start with netService: %@, with addresses: %@", netService, netService.addresses);
    }
    else if (host != nil) {
        NSLog(@"send did start with host: %@, and port: %hu", host, port);
    }
}

- (void)updateStatus:(NSString *)statusString
{
    assert(statusString != nil);
}

- (void)sendDidStopWithStatus:(NSString *)statusString
{
    NSLog(@"send did stop with status: %@", statusString);
    [delegate sendDidStopWithStatus:statusString];
}


#pragma mark * Core transfer code

// This is the code that actually does the networking.

// Because buffer is declared as an array, you have to use a custom getter.
// A synthesised getter doesn't compile.

- (uint8_t *)buffer
{
    return self->_buffer;
}

- (BOOL)isSending
{
    return (self.networkStream != nil);
}

- (void)startSendFileAtPath:(NSString *)filePath
{
    assert(filePath != nil);
    
    NSData* fileData = [NSData dataWithContentsOfFile:filePath];
    
    [self startSendData:fileData];
}

- (void)startSendData:(NSData *)data
{
    NSOutputStream *    output;
    BOOL                success;
    // we got one from initWithNetService
    //NSNetService *      netService;
    
    assert(data != nil);
    
    assert(self.networkStream == nil);      // don't tap send twice in a row!
    assert(self.fileStream == nil);         // ditto
    
    // add a header to the data we want to send
    UInt16 header = magicNumberSend;
    NSMutableData* dataWithHeader = [NSMutableData dataWithBytes:&header length:sizeof(UInt16)];
    [dataWithHeader appendData:data];
    
    // Open a stream for the data we're going to send.
    self.fileStream = [NSInputStream inputStreamWithData:dataWithHeader];
    assert(self.fileStream != nil);
    
    [self.fileStream open];
    
    // Open a stream to the server, finding the server via Bonjour.  Then configure
    // the stream for async operation.
    
    // if we're using a netService:
    
    // Until <rdar://problem/6868813> is fixed, we have to use our own code to open the streams
    // rather than call -[NSNetService getInputStream:outputStream:].  See the comments in
    // QNetworkAdditions.m for the details.
    
    if (netService != nil) {
        success = [netService qNetworkAdditions_getInputStream:NULL outputStream:&output];
        assert(success);
    }
    
    // if we're using a host and port
    if (host != nil) {
        CFStringRef cfHost = (__bridge CFStringRef)host;
        CFWriteStreamRef    writeStream;
        CFStreamCreatePairWithSocketToHost(NULL, cfHost, port, NULL, &writeStream);
        success = (writeStream != NULL);
        assert(success);
        // example from https://developer.apple.com/library/ios/documentation/cocoa/conceptual/streams/articles/networkstreams.html
        output = (__bridge_transfer NSOutputStream *)writeStream;
    }
    
    self.networkStream = output;
    [self.networkStream setDelegate:self];
    [self.networkStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.networkStream open];
    
    // Tell the UI we're sending.
    
    [self sendDidStart];
}

- (void)stopSendWithStatus:(NSString *)statusString
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
    self.bufferOffset = 0;
    self.bufferLimit  = 0;
    [self sendDidStopWithStatus:statusString];
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
            assert(NO);     // should never happen for the output stream
        } break;
        case NSStreamEventHasSpaceAvailable: {
            [self updateStatus:@"Sending"];
            
            // If we don't have any data buffered, go read the next chunk of data.
            
            if (self.bufferOffset == self.bufferLimit) {
                NSInteger   bytesRead;
                
                bytesRead = [self.fileStream read:self.buffer maxLength:kSendBufferSize];
                
                if (bytesRead == -1) {
                    [self stopSendWithStatus:@"File read error"];
                } else if (bytesRead == 0) {
                    [self stopSendWithStatus:nil];
                } else {
                    self.bufferOffset = 0;
                    self.bufferLimit  = bytesRead;
                }
            }
            
            // If we're not out of data completely, send the next chunk.
            
            if (self.bufferOffset != self.bufferLimit) {
                NSInteger   bytesWritten;
                
                bytesWritten = [self.networkStream write:&self.buffer[self.bufferOffset] maxLength:self.bufferLimit - self.bufferOffset];
                assert(bytesWritten != 0);
                if (bytesWritten == -1) {
                    [self stopSendWithStatus:@"Network write error"];
                } else {
                    self.bufferOffset += bytesWritten;
                }
            }
        } break;
        case NSStreamEventErrorOccurred: {
            NSLog(@"sender stream error: %@", [aStream streamError]);
            [self stopSendWithStatus:@"Stream open error"];
        } break;
        case NSStreamEventEndEncountered: {
            // ignore
        } break;
        default: {
            assert(NO);
        } break;
    }
}

// TODO:    put the actions in another class
//          the sender class should only know how to send data
#pragma mark * Actions

- (IBAction)cancelAction:(id)sender
{
    #pragma unused(sender)
    // stops the stream
    [self stopSendWithStatus:@"Cancelled"];
}

@end
