//
//  FileManager.h
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileManager : NSObject

+ (NSString *)documentsPath;
+ (NSString *)booksFolderPath;
+ (NSString *)generateUUIDString;
+ (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix;
+ (void)eraseAllFilesInDirectory:(NSString *)directory;

- (NSArray *)getListOfFilesToUpdateFromArray:(NSArray *)array;
- (BOOL)saveData:(NSData *)data AtPath:(NSString *)path;
- (BOOL)commitReceivedFiles;

- (NSString *)getIndexPathOfBook:(NSString *)bookName;
- (NSString *)getIndexPathOfLastUpdatedBook;

@end
