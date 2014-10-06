//
//  Connection.m
//  Platypus2
//
//  Created by Raphael on 25.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "Connection.h"
#import "ReceiveServer.h"
#import "Sender.h"
#import "FileManager.h"
#import "NetworkUtilities.h"

@interface Connection ()

@property ReceiveServer *receiver;
@property Sender *sender;
@property FileManager *fileManager;

@end

@implementation Connection

@synthesize delegate;
@synthesize connectionIsOn;
@synthesize receiver, sender, fileManager;
@synthesize netService, host, port, computerName;

- (void)initConnectionWithComputer:(NSNetService *)_netService {
    netService = _netService;
    [self initConnectionWithComputerName:[netService name]];
}

- (void)initConnectionWithComputerName:(NSString *)_computerName {
    computerName = _computerName;
    
    // we're going to send files to a specific service type, not the AuthorService
    NSString *deviceName = [self getDeviceName];
    
    NSString *serviceName = [NSString stringWithFormat:@"%@%@", computerName, deviceName];
    NSLog(@"Sending to service of type: %@ and name: %@", @"_PlatypusAuthorTransfer._tcp.", serviceName);
    sender = [[Sender alloc] initWithType:@"_PlatypusAuthorTransfer._tcp." AndName:serviceName];
    
    NSString *type = [NSString stringWithFormat:@"_Platypus-%@._tcp.", computerName];
    receiver = [[ReceiveServer alloc] init];
    receiver.delegate = self;
    NSLog(@"Server started with type: %@ and name: %@", type, deviceName);
    // passing name = @"" use default device name handling of NSNetService
    [receiver startServerWithType:type AndName:deviceName];
    
    fileManager = [[FileManager alloc] init];
    
    connectionIsOn = YES;
}

- (void)initConnectionWithHost:(NSString *)_host AndPort:(UInt16)_port {
    //NSLog(@"init connection with host %@ and port %hu", _host, _port);
    host = _host;
    port = _port;
    sender = [[Sender alloc] initWithHost:host AndPort:port];
    receiver = [[ReceiveServer alloc] init];
    receiver.delegate = self;
    [receiver startServerWithType:nil AndName:nil];
    
    fileManager = [[FileManager alloc] init];
    
    connectionIsOn = YES;
}

- (NSString *)getDeviceUUID {
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSString *uuid = [userDefault objectForKey:@"prefixUUID"];
    if (uuid == nil) {
        uuid = [FileManager generateUUIDString];
        uuid = [uuid substringToIndex:8];
        [userDefault setObject:uuid forKey:@"prefixUUID"];
        [userDefault synchronize];
    }
    return uuid;
}

- (NSString *)getDeviceName {
    NSString *deviceName = [[UIDevice currentDevice] name];
    NSString *uuid = [self getDeviceUUID];
    return [NSString stringWithFormat:@"%@%@", uuid, deviceName];
}

- (void)restart {
    // don't restart if you've already started
    if (connectionIsOn) return;
    
    //NSLog(@"%@ restarting connection", self);
    if (computerName != nil) {
        [self initConnectionWithComputerName:computerName];
    }
    else if (host != nil) {
        [self initConnectionWithHost:host AndPort:port];
    }
    else {
        NSLog(@"** warning: trying to restart a connection that never started.");
    }
}

- (void)stop:(NSString *)reason {
    //NSLog(@"%@ is stopping", self);
    if (receiver != nil) {
        [receiver stopServer:reason];
    }
    connectionIsOn = NO;
}

// Block0 means we received an array with all the file in a project
// We send back an array with the files we need to update
- (void)receivedDataBlock0WithFileArray:(NSData *)data {
    NSArray *array = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    if (array != NULL) {
        NSArray *pathArray = [fileManager getListOfFilesToUpdateFromArray:array];
        NSLog(@"files to update: %@", pathArray);
        
        if ([pathArray count] <= 0) {
            NSLog(@"Book is up to date, no need to ask for new files.");
        } else {
            // notify delegate that we're beginning an update
            // [delegate bookUpdateStarted];
        }
        
        // send an array of string of the paths of the files we need
        UInt8 blockID = 10;
        NSMutableData* arrayData = [NSMutableData dataWithBytes:&blockID length:sizeof(UInt8)];
        [arrayData appendData:[NSKeyedArchiver archivedDataWithRootObject:pathArray]];
        [sender startSendData:arrayData];
    } else {
        NSLog(@"Data couldn't be converted to array from data block with ID 0.");
    }
}

// Block1 means we received a file
- (void)receivedDataBlock1WithFile:(NSData *)data {
    
    // get the path string size
    NSRange range = NSMakeRange(0, sizeof(UInt32));
    UInt32 pathStringSize;
    [data getBytes:&pathStringSize range:range];
    // get the path string from data
    NSRange pathStringRange = NSMakeRange(sizeof(UInt32), pathStringSize);
    NSData *stringData = [data subdataWithRange:pathStringRange];
    NSString *path = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    // append to "Documents" folder path
    assert(path != nil);
    NSString *filePath = [[FileManager documentsPath] stringByAppendingPathComponent:path];
    // get the file data from data block
    NSRange fileRange = NSMakeRange((sizeof(UInt32) + pathStringSize), (data.length - (sizeof(UInt32) + pathStringSize)));
    NSData *fileData = [data subdataWithRange:fileRange];
    
    // prepare message
    UInt8 blockID = 11;
    NSMutableData* dataWithHeader = [NSMutableData dataWithBytes:&blockID length:sizeof(UInt8)];
    // save file
    // if success is true, PlatypusAuthor will send the next file
    BOOL success = [fileManager saveData:fileData AtPath:filePath];
    // add success value in message
    [dataWithHeader appendBytes:&success length:sizeof(BOOL)];
    
    // send message
    [sender startSendData:dataWithHeader];
}

// Block3 means we got the port to which we can answer to the author
- (void)receivedDataBlock3WithPort:(NSData *)data {
    NSRange range = NSMakeRange(0, sizeof(UInt16));
    //UInt16 newPort;
    [data getBytes:&port range:range];
    
    sender.port = port;
    
    UInt8 blockID = 12;
    NSData* dataWithHeader = [NSData dataWithBytes:&blockID length:sizeof(UInt8)];
    [sender startSendData:dataWithHeader];
}

#pragma mark ReceiveServerDelegate methods implementation

- (void)serverDidStartOnPort:(NSInteger)serverPort {
    // if we created a server without netService (without bonjour and via host and port)
    if (receiver.netService == nil) {
        // we send information about the server directly to the host
        // useful if bonjour services are blocked by a proxy
        
        // add port
        UInt16 _port = serverPort;
        NSMutableData *data = [NSMutableData dataWithBytes:&_port length:sizeof(UInt16)];
        
        // add host
        NSString *selfIP = [NetworkUtilities getIPAddress:YES];
        NSData *hostStringData = [selfIP dataUsingEncoding:NSUTF8StringEncoding];
        UInt32 hostStringSize = (UInt32)hostStringData.length;
        [data appendBytes:&hostStringSize length:sizeof(UInt32)];
        [data appendData:hostStringData];
        
        // add device name
        NSString *deviceName = [[UIDevice currentDevice] name];
        
        NSData *nameData = [deviceName dataUsingEncoding:NSUTF8StringEncoding];
        [data appendData:nameData];
        
        // send the data
        NSLog(@"host server did start, sending infos to %@ port %hu", [sender host], [sender port]);
        [sender startSendData:data];
    }
}

// the receiveServer can send a path to a temp file
// we're not using it since we're modifing the data with headers
// so we cannot just copy the tmp file to its final destination
// the tmp file is just used as a buffer
- (void)receivedDataAtPath:(NSString *)path {
    
}

- (void)receivedData:(NSData *)data {
    // get the block id
    NSRange range = NSMakeRange(0, sizeof(UInt8));
    // convert to UInt8
    UInt8 blockID;
    [data getBytes:&blockID range:range];
    
    NSData* dataWithoutHeader = [data subdataWithRange:NSMakeRange(sizeof(UInt8), data.length - sizeof(UInt8))];
    
    switch (blockID) {
        case 0: {
            [self receivedDataBlock0WithFileArray:dataWithoutHeader];
            break;
        }
        case 1: {
            // we received a file
            [self receivedDataBlock1WithFile:dataWithoutHeader];
            break;
        }
        case 2: {
            // that was the last file.
            // load index.html in the book we just updated (received in the message)
            //NSString *bookName = [NSString stringWithUTF8String:[dataWithoutHeader bytes]];
            //NSString *indexPath = [fileManager getIndexPathOfBook:bookName];
            if ([fileManager commitReceivedFiles]) {
                NSLog(@"book has been updated");
                NSString *indexPath = [fileManager getIndexPathOfLastUpdatedBook];
                // tell the network manager that we're done.
                // The network manager will then tell the main ViewController that we're done.
                [delegate bookUpdateEnded:indexPath];
            } else {
                NSLog(@"book update failed...");
            }
            break;
        }
        case 3: {
            // we're using servers manually setup
            // we should get the port we have to use.
            [self receivedDataBlock3WithPort:dataWithoutHeader];
            break;
        }
        default:
            break;
    }
    
}

@end
