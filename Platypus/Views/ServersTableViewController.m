//
//  ServersTableViewController.m
//  Platypus2
//
//  Created by Raphael on 22.08.14.
//  Copyright (c) 2014 Aprobado. All rights reserved.
//

#import "ServersTableViewController.h"
#import "ActivableServer.h"
#import "../Network/Targets/Targets.h"
#import "../Network/Targets/Target.h"
#import "../Network/Targets/NetServiceTarget.h"
#import "../Network/Targets/HostTarget.h"

NSInteger const defaultPort = 40905;

@interface ServersTableViewController ()

@property (weak, nonatomic) IBOutlet UIBarButtonItem *backButton;
@property Targets *targets;

@end

@implementation ServersTableViewController

@synthesize delegate;
@synthesize targets;
@synthesize activableServers, backButton, presentServices;
@synthesize manuallyAddedServers;

// must call that when instantiating the controller
- (void)initProperties {
    targets = [[Targets alloc] init];
    
    // targets inititalization loads recorded targets, so we need to tell the delegate
    // that an update occured
    [delegate activeServersUpdated];
    
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    // register tap action on author icon
    backButton.target = self;
    backButton.action = @selector(backButtonTapped);
}

- (void)backButtonTapped {
    [delegate backTapped];
}

- (IBAction)addAuthorManuallyTapped:(id)sender {
    UInt16 _port = 0;
    NSString *address = @"ip-address";
    
    [targets addHostTargetWithName:@"CPU Name" Address:address AndPort:_port Activated:NO];
    
    //NSLog(@"server added manually, count: %lu", (unsigned long)[manuallyAddedServers count]);
    [self.tableView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)serverCount {
    return [targets deviceCount];
}

// receiving services list from the serverBrowser
- (void)updatePresentServicesWithNetServices:(NSMutableArray *)services {
    [targets updateNetServiceTargetsWithArray:services];
    [self.tableView reloadData];
}

- (void)switchStateChanged:(id)sender {
    // modify the activableServers list...
    // [sender superview] is a UITableViewCellScrollView...
    UITableViewCell* cell = (UITableViewCell *)[sender superview];
    
    // if we're on iOS 7, we need to get the upper level view
    if ([cell class] != [UITableViewCell class]) {
        cell = (UITableViewCell *)[cell superview];
    }
    
    assert([cell class] == [UITableViewCell class]);
    
    // [cell superview] is a UITableViewWrapperView...
    //UITableView* table = (UITableView *)[[cell superview] superview];
    NSIndexPath* pathOfTheCell = [self.tableView indexPathForCell:cell];
    NSInteger rowOfTheCell = [pathOfTheCell row];
    
    id target = [targets getDeviceAtIndex:rowOfTheCell];
    if ([target class] == [HostTarget class]) { // host targets must have valid informations
        HostTarget *hostTarget = (HostTarget *)target;
        if (![hostTarget isValid]) {
            UISwitch *thatSwitch = (UISwitch *)sender;
            [thatSwitch setOn:NO animated:YES];
        }
    }
    
    [targets targetStateChangedAtIndex:rowOfTheCell WithValue:[sender isOn]];
    [self.tableView reloadData];
    
    [delegate activeServersUpdated];
}

- (NSMutableArray *)getAllowedServices {
    return [targets getActiveDevices];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([[targets getDevices] count] > 0) return 1;
    else return 0;
    // #warning Potentially incomplete method implementation.
    // Return the number of sections.
    // return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = [[targets getDevices] count];
    return numberOfRows;
    // #warning Incomplete method implementation.
    // Return the number of rows in the section.
    // return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"Cell";
    
    id target = [targets getDeviceAtIndex:[indexPath indexAtPosition:1]];
    if ([target class] == [HostTarget class]) {
        CellIdentifier = @"EditableCell";
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        //add a switch
        UISwitch *switchview = [[UISwitch alloc] initWithFrame:CGRectZero];
        switchview.on = [target active];
        [switchview addTarget:self action:@selector(switchStateChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchview;
        
        if ([target class] == [HostTarget class]) {
            HostTarget *hostTarget = (HostTarget *)target;
            
            // ip label
            UILabel *addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 100, 30)];
            addressLabel.text = @"IP Address :";
            
            // ip field
            UITextField *addressField = [self createTextFieldWithString:@"ip-address" ReturnKey:UIReturnKeyDone AndFrame:CGRectMake(130, 10, 150, 30)];
            
            /*
            // add port label
            UILabel *portLabel = [[UILabel alloc] initWithFrame:CGRectMake(290, 10, 50, 30)];
            portLabel.text = @"Port :";
            
            // port field
            UITextField *portField = [self createTextFieldWithString:@"port" ReturnKey:UIReturnKeyDone AndFrame:CGRectMake(350, 10, 75, 30)];
            */
            
            // fill the field with host target values
            addressField.text = hostTarget.host;
            //portField.text = [NSString stringWithFormat:@"%hu", hostTarget.port];
            
            // adding subviews
            [cell.contentView addSubview:addressLabel];
            [cell.contentView addSubview:addressField];
            //[cell.contentView addSubview:portLabel];
            //[cell.contentView addSubview:portField];
        }
        
    }
    if ([target class] == [NetServiceTarget class]) {
        NetServiceTarget *netServiceTarget = (NetServiceTarget *)target;
        cell.textLabel.text = netServiceTarget.name;
    }
    
    return cell;
}

- (UITextField *)createTextFieldWithString:(NSString *)placeholderString ReturnKey:(UIReturnKeyType)returnKeyType AndFrame:(CGRect)rect {
    UITextField *textField = [[UITextField alloc] initWithFrame:rect];
    textField.adjustsFontSizeToFitWidth = YES;
    textField.textColor = [UIColor blackColor];
    
    textField.placeholder = placeholderString;
    //textField.keyboardType = UIKeyboardTypeDecimalPad;
    textField.returnKeyType = returnKeyType;
    
    textField.backgroundColor = [UIColor whiteColor];
    textField.autocorrectionType = UITextAutocorrectionTypeNo; // no auto correction support
    textField.autocapitalizationType = UITextAutocapitalizationTypeNone; // no auto capitalization support
    textField.textAlignment = NSTextAlignmentLeft;
    textField.tag = 0;
    textField.delegate = self;
    
    textField.clearButtonMode = UITextFieldViewModeNever; // no clear 'x' button to the right
    [textField setEnabled: YES];
    
    return textField;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    /*
    if (textField.returnKeyType == UIReturnKeyNext) {
        UITableViewCell *cell = (UITableViewCell *)[textField superview];
        UITextField *nextField = (UITextField *)[[cell subviews] objectAtIndex:3]; // portTextField
        [nextField becomeFirstResponder];
    }
    */
    if (textField.returnKeyType == UIReturnKeyDone) {
        [textField resignFirstResponder];
        
        [self saveInfosFromTextField:textField];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    [self saveInfosFromTextField:textField];
}

- (void)saveInfosFromTextField:(UITextField *)textField {
    // save the whole row so we don't care if we're editing a host or a port.
    UITableViewCell *cell = (UITableViewCell *)[[textField superview] superview];
    //NSLog(@"cell class: %@", [cell class]);
    //NSLog(@"cell contentView subviews: %@", [[cell contentView] subviews]);
    
    assert([cell class] == [UITableViewCell class]);
    
    UITextField *hostField = (UITextField *)[[[cell contentView] subviews] objectAtIndex:1]; // hostTextField
    //NSLog(@"hostField class: %@", [hostField class]);
    //UITextField *portField = (UITextField *)[[[cell contentView] subviews] objectAtIndex:3]; // portTextField
    
    assert([hostField class] == [UITextField class]);
    
    //UITableViewCell *tableCell = (UITableViewCell *)[[cell superview] superview];
    //NSLog(@"tableCell class: %@", [tableCell class]);
    NSIndexPath* pathOfTheCell = [self.tableView indexPathForCell:cell];
    NSInteger rowOfTheCell = [pathOfTheCell row];
    
    assert(rowOfTheCell > -1);
    
    // save field entries to the correct target
    HostTarget *target = (HostTarget *)[targets getDeviceAtIndex:rowOfTheCell];
    target.host = [hostField text];
    target.port = defaultPort;//[[portField text] integerValue];
    NSLog(@"port saved for target: %hu", target.port);
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Table view delegate

// In a xib-based application, navigation from a table can be handled in -tableView:didSelectRowAtIndexPath:
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Navigation logic may go here, for example:
    // Create the next view controller.
    <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:<#@"Nib name"#> bundle:nil];
    
    // Pass the selected object to the new view controller.
    
    // Push the view controller.
    [self.navigationController pushViewController:detailViewController animated:YES];
}
*/

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
