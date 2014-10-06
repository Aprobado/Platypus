//
//  FileManager.m
//  Platypus2
//
//  Created by Raphael on 26.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "FileManager.h"

@interface FileManager ()

@property NSString *lastUpdatedBook;
@property NSMutableArray *tempFiles;
@property NSMutableArray *uselessFiles;

@end

@implementation FileManager

@synthesize lastUpdatedBook, tempFiles, uselessFiles;

+ (NSString *)documentsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    assert(documentsPath != nil);
    
    return documentsPath;
}

+ (NSString *)booksFolderPath {
    return [[FileManager documentsPath] stringByAppendingPathComponent:@"Books"];
}

+ (NSString *)generateUUIDString {
    CFUUIDRef   uuid;
    NSString *  uuidStr;
    
    uuid = CFUUIDCreate(NULL);
    assert(uuid != NULL);
    
    uuidStr = CFBridgingRelease( CFUUIDCreateString(NULL, uuid) );
    
    CFRelease(uuid);
    
    return uuidStr;
}

+ (NSString *)pathForTemporaryFileWithPrefix:(NSString *)prefix
{
    NSString *  result;
    NSString *  uuidStr = [FileManager generateUUIDString];
    
    result = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%@", prefix, uuidStr]];
    assert(result != nil);
    
    return result;
}

+ (void)eraseAllFilesInDirectory:(NSString *)directory {
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
    for (NSString *filename in fileArray)  {
        [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
    }
}

// Creates an array of all the files in a folder (recursively)
- (void)addFilesInFolderPath:(NSString *)folderPath ToArray:(NSMutableArray *)array {
    // NSString *absolutePath = [htmlFolderPath stringByAppendingPathComponent:folderPath];
    NSString *absolutePath = [[FileManager booksFolderPath] stringByAppendingPathComponent:folderPath];
    
    NSArray *content = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:absolutePath error:nil];
    
    for (NSString *file in content) {
        // ignore invisible files
        if ([file characterAtIndex:0] == [@"." characterAtIndex:0]) continue;
        
        NSString *fileRelativePath = [folderPath stringByAppendingPathComponent:file];
        NSString *fileAbsolutePath = [absolutePath stringByAppendingPathComponent:file];
        
        BOOL isDirectory;
        [[NSFileManager defaultManager] fileExistsAtPath:fileAbsolutePath isDirectory:&isDirectory];
        
        if (isDirectory) {
            [self addFilesInFolderPath:fileRelativePath ToArray:array];
        }
        else {
            // add file to the array
            [array addObject:fileRelativePath];
        }
    }
}
- (NSArray *)getArrayOfFilesInBook:(NSString *)book {
    NSMutableArray* array = [[NSMutableArray alloc] init];
    // folder path is relative to the edited book path
    [self addFilesInFolderPath:book ToArray:array];
    return array;
}

- (BOOL)fileNeedsUpdate:(NSDictionary *)file {
    
    assert([file[@"path"] isKindOfClass:[NSString class]]);
    assert([file[@"date"] isKindOfClass:[NSDate class]]);
    
    // file[@"path"] contains the book name to know in which book we have to look ex:"BookName/index.html"
    NSString *fullPath = [[FileManager booksFolderPath] stringByAppendingPathComponent:file[@"path"]];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:nil]) {
        // file exists already, but is it up to date?
        
        // get date attribute
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
        NSDate *date = attributes[NSFileModificationDate];
        // this date is the date the file has been uploaded on the iOS device
        // not the actual file creation date. But should be reliable enough.
        
        NSComparisonResult result = [date compare:file[@"date"]];
        
        if (result == NSOrderedAscending) {
            // the file is more recent, get it
            return YES;
        } else {
            // the file sent is older or the same, ignore it
            return NO;
        }
    } else {
        // if file doesn't exist, we need the update
        return YES;
    }
    
    return NO;
}

- (BOOL)findFile:(NSString *)file inArray:(NSArray *)array {
    for (NSDictionary *dic in array) {
        if ([file isEqualToString:dic[@"path"]]) return YES;
    }
    return NO;
}

- (NSMutableArray *)findUselessFilesInBook:(NSString *)book withArray:(NSArray *)array {
    NSMutableArray *uselessList = [[NSMutableArray alloc] init];
    NSArray *allFiles = [self getArrayOfFilesInBook:book];
    for (NSString *file in allFiles) {
        if (![self findFile:file inArray:array]) {
            [uselessList addObject:file];
        }
    }
    return uselessList;
}

- (NSArray *)getListOfFilesToUpdateFromArray:(NSArray *)array {
    
    // it's the beginning of an update: clean up the tempFiles list
    if (tempFiles == nil) tempFiles = [[NSMutableArray alloc] init];
    else [tempFiles removeAllObjects];
    
    NSMutableArray *pathArray = [[NSMutableArray alloc] init];
    
    NSRange firstSlash = [[[array objectAtIndex:0] objectForKey:@"path"] rangeOfString:@"/"];
    assert(firstSlash.location != NSNotFound);
    
    lastUpdatedBook = [[[array objectAtIndex:0] objectForKey:@"path"] substringToIndex:firstSlash.location];
    
    for (NSDictionary *dic in array) {
        if ([self fileNeedsUpdate:dic]){
            // strip book name from path
            //NSRange firstSlash = [dic[@"path"] rangeOfString:@"/"];
            //assert(firstSlash.location != NSNotFound);
            
            NSRange pathRange = NSMakeRange(firstSlash.location+1,
                                            [dic[@"path"] length] - (firstSlash.location + 1));
            NSString *path = [dic[@"path"] substringWithRange:pathRange];
                              
            [pathArray addObject:path];
        }
    }
    
    uselessFiles = [self findUselessFilesInBook:lastUpdatedBook withArray:array];
    
    return pathArray;
}

// we save internally in temp files before making a commit of all files at once.
- (BOOL)saveData:(NSData *)data AtPath:(NSString *)path {
    // important!
    // create folders we need if they don't exist
    // or else file creation won't work
    NSRange folderRange = [path rangeOfString:@"/" options:NSBackwardsSearch];
    if (folderRange.location != NSNotFound) {
        NSString *parentFolderPath = [path substringWithRange:NSMakeRange(0, folderRange.location)];
        if (![[NSFileManager defaultManager] fileExistsAtPath:parentFolderPath]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:parentFolderPath withIntermediateDirectories:YES attributes:nil error:nil];
        }
    }
    
    NSString *tempPath = [FileManager pathForTemporaryFileWithPrefix:@"tmp"];
    
    // write data into filePath
    if ([data writeToFile:tempPath atomically:YES]) {
        // the file has been written successfully
        if (tempFiles == nil) tempFiles = [[NSMutableArray alloc] init];
        [tempFiles addObject:[NSDictionary dictionaryWithObjectsAndKeys:path, @"filePath", tempPath, @"tempPath", nil]];
        return YES;
    } else {
        // couldn't write file
        return NO;
    }
}

- (BOOL)commitReceivedFiles {
    // every file in tempFiles is moved to its destination path
    for (NSDictionary *dico in tempFiles) {
        NSError *error = nil;
        NSFileManager *manager = [NSFileManager defaultManager];
        NSString *tempPath = [dico objectForKey:@"tempPath"];
        NSString *filePath = [dico objectForKey:@"filePath"];
        
        // if the file already exists, erase it
        if ([manager fileExistsAtPath:filePath]) {
            NSLog(@"file path: %@", filePath);
            if (![manager removeItemAtPath:filePath error:&error]) {
                NSLog(@"removing file error: %@", error);
                assert(NO);
            }
        }
        // move the temp file to its destination
        if (![manager moveItemAtPath:tempPath toPath:filePath error:&error]) {
            NSLog(@"moving file error: %@", error);
            assert(NO);
        }
    }
    
    // we moved all the files correctly
    [tempFiles removeAllObjects];
    
    [self eraseUselessFiles];
    
    return YES;
}

- (void)eraseUselessFiles {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error = nil;
    for (NSString *file in uselessFiles) {
        NSString *filePath = [[FileManager booksFolderPath] stringByAppendingPathComponent:file];
        if (![manager removeItemAtPath:filePath error:&error]) {
            NSLog(@"removing file error: %@", error);
            assert(NO);
        }
    }
    [uselessFiles removeAllObjects];
}

- (NSString *)getIndexPathOfBook:(NSString *)bookName {
    NSString *indexPath = [[FileManager booksFolderPath] stringByAppendingPathComponent:bookName];
    indexPath = [indexPath stringByAppendingPathComponent:@"index.html"];
    return indexPath;
}

- (NSString *)getIndexPathOfLastUpdatedBook {
    return [self getIndexPathOfBook:lastUpdatedBook];
}

@end
