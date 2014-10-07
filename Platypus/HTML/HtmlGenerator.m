//
//  htmlGenerator.m
//  Platypus
//
//  Created by Raphael on 05.06.14.
//  Copyright (c) 2014 Raphael Munoz. All rights reserved.
//

#import "HtmlGenerator.h"
#import "FileManager.h"

@implementation HtmlGenerator

// This creates an index.html file in the documents directory inside the app
// that lists all the books availables in the platypus app.
// It then returns the path of the file that must be loaded in the webview:
// If there's only one book, it returns the path of that book instead of the freshly created index.html
+ (NSString *)createHtmlBookIndex
{
	// begin html index
	NSString *html = @"<!DOCTYPE html><html><head><title>Platypus Index</title></head><body>";
	
	// get the App Documents path
	NSArray *documentsFolderPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [documentsFolderPaths objectAtIndex:0]; // Get documents folder
	
	// get the Books folder path and creates it if it doesn't already exists
	NSString *booksPath = [documentsDirectory stringByAppendingPathComponent:@"/Books"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:booksPath])
		[[NSFileManager defaultManager] createDirectoryAtPath:booksPath withIntermediateDirectories:NO attributes:nil error:nil];
	
	// get the list of folders inside the Books folder
	NSFileManager *manager = [NSFileManager defaultManager];
	NSArray *booksFolderArray = [manager contentsOfDirectoryAtPath:booksPath error:nil];
	// NSLog(@"documents: %@", documentsFolderArray); // uncomment to display the folders inside the Books folder
	
	// add css style in the html document
	NSUInteger nbBooks = [booksFolderArray count];
	NSString *style = [NSString stringWithFormat:@"<style type=\"text/css\">html{height:100%%;}body{height:98%%;font-family:\"Helvetica\", sans-serif;font-weight:100;font-size:50px;text-align:center;}a{display:block;height:%f%%;text-decoration:none;}.book{display:block;width:100%%;height:100%%;color:black;border:solid gray 1px;}.book p{position:relative;top:-webkit-calc(50%% - 30px);margin:0;padding:0}</style>", 100.f/(float)nbBooks];
	html = [html stringByAppendingString:style];
	
    // if no books
    if (nbBooks == 0) {
        NSString* noBookWarning = @"<p>Oh! There's no book here!</p>";
        html = [html stringByAppendingString:noBookWarning];
    }
    
	// add divs for each folder in Books
	for (int i = 0; i < booksFolderArray.count; i++) {
		NSString *folderName = [booksFolderArray objectAtIndex:i];
		//NSString *bookDiv = [NSString stringWithFormat:@"<tr><td><div class=\"book\"><a href=\"Books/%@/index.html\">%@</a></div></td></tr>", folderName, folderName];
        NSString *indexPath = [FileManager getIndexPathOfBook:folderName];
        NSString *indexFile = [indexPath lastPathComponent];
		NSString *bookDiv = [NSString stringWithFormat:@"<a href=\"Books/%@/%@\"><span class=\"book\"><p>%@</p></span></a>", folderName, indexFile, folderName];
		html = [html stringByAppendingString:bookDiv];
	}
	
	// end the html
	html = [html stringByAppendingString:@"</body></html>"];
	
	// write the html file at htmlPath (Documents/index.html)
	NSString *htmlPath = [documentsDirectory stringByAppendingPathComponent:@"index.html"];
	[html writeToFile:htmlPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
	// NSLog(@"%@", html); // uncomment to display the html content
	
    // if there's only one book, send the book path instead
    if (booksFolderArray.count == 1) {
        NSString *bookFolderName = [booksFolderArray objectAtIndex:0];
        NSString *indexPath = [FileManager getIndexPathOfBook:bookFolderName];
        htmlPath = indexPath;
    }
    
	return htmlPath;
}

@end
