//
//  ViewController.m
//  Platypus2
//
//  Created by Raphael on 19.06.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "ViewController.h"
#import "NetworkManager.h"
#import "HtmlGenerator.h"
#import "ServersTableViewController.h"
#import "ActivableServer.h"

@interface ViewController ()
            
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIImageView *authorIcon;

@property NetworkManager *networkManager;

@end

@implementation ViewController

@synthesize webView, networkManager, authorIcon;

+ (NSString *)uuid
{
    CFUUIDRef uuidRef = CFUUIDCreate(NULL);
    CFStringRef uuidStringRef = CFUUIDCreateString(NULL, uuidRef);
    CFRelease(uuidRef);
    return (__bridge NSString *)uuidStringRef;
}

- (void)viewDidLoad {
    // get the unique ID of the app on this device
    
    // if it doesn't exist, generate it with "+ (NSString *)uuid"
    // and store it in the preferences
    
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    NSString *indexPath = [HtmlGenerator createHtmlBookIndex];
    NSURL *url = [NSURL URLWithString:indexPath];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    
    //webView.scalesPageToFit = YES;
    //webView.autoresizesSubviews = YES;
    //webView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth);
    
    // set size and alpha of author icon to zero
    authorIcon.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0, 0);
    authorIcon.alpha = 0;
    // register tap action on author icon
    UITapGestureRecognizer *authorIconTap =  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(authorIconTapping:)];
    [authorIconTap setNumberOfTapsRequired:1];
    [authorIcon addGestureRecognizer:authorIconTap];
    
    // if we're in author mode, we always show the edit button
    // that way we can create a server manually
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"author-mode"]) {
        [self showAuthorIcon];
    }
    
    [webView loadRequest:req];
    
    //[webView loadHTMLString:@"<html><h1>Hello!</h1></html>" baseURL:nil];
    
    networkManager = [[NetworkManager alloc] initWithDelegate:self];
}

- (void)authorIconTapping:(UIGestureRecognizer *)recognizer {
    // NSLog(@"author icon tapped");
    [self presentViewController:networkManager.serversView animated:YES completion:nil];
    [self hideAuthorIcon];
    //[self.navigationController pushViewController:serversView animated:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark NetworkManagerDelegate implementations

- (void)bookUpdateStarted {
    [webView loadHTMLString:@"<html><h1>Updating...</h1></html>" baseURL:nil];
}

- (void)bookUpdateEnded:(NSString *)bookHtmlIndex {
    NSLog(@"Loading book: %@", bookHtmlIndex);
    NSURL *url = [NSURL URLWithString:bookHtmlIndex];
    NSURLRequest *req = [NSURLRequest requestWithURL:url];
    [webView loadRequest:req];
}

- (void)showAuthorIcon {
    if (authorIcon.alpha > 0) {
        return;
    }
    
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         authorIcon.transform = CGAffineTransformScale(CGAffineTransformIdentity, 1, 1);
                         authorIcon.alpha = 1;
                     }
                     completion:^(BOOL finished) {
                     }
     ];
}

- (void)hideAuthorIcon {
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"author-mode"]) return;
    
    if (authorIcon.alpha < 1) {
        return;
    }
    
    [UIView animateWithDuration:0.5
                          delay:0
                        options:UIViewAnimationOptionBeginFromCurrentState| UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         authorIcon.transform = CGAffineTransformScale(CGAffineTransformIdentity, 0, 0);
                         authorIcon.alpha = 0;
                     }
                     completion:^(BOOL finished) {
                     }
     ];
}

// Back button in ServersTableView
- (void)backTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
