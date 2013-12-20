//
//  PresetController.m
//  ArmKeyBoard
//
//  Created by tangkk on 19/12/13.
//  Copyright (c) 2013 tangkk. All rights reserved.
//

#import "PresetController.h"

@interface PresetController () {
    int selectedRow;
}

@property (strong, nonatomic) NSMutableDictionary *presets;
@property (strong, nonatomic) IBOutlet UITableView *presetTable;

@end

@implementation PresetController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    selectedRow = -1;
    _presets = [self readFromFile];
    [self printDictionary:_presets];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - helper
- (void) printDictionary: (NSDictionary *)dict {
    for (NSString *key in [dict allKeys]) {
        NSLog(@"key: %@", key);
        NSArray *arr = [_presets objectForKey:key];
        for (NSArray *array in arr) {
            NSLog(@"%@, %@, %@", [array objectAtIndex:0], [array objectAtIndex:1], [array objectAtIndex:2]);
        }
    }
}

#pragma mark - read/write
- (NSMutableDictionary *) readFromFile {
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                              NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"Preset.plist"];
    return [NSDictionary dictionaryWithContentsOfFile:plistPath];
}

- (void) writeToFile: (NSMutableDictionary *)preset {
    NSString *error;
    NSString *rootPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                              NSUserDomainMask, YES) objectAtIndex:0];
    NSString *plistPath = [rootPath stringByAppendingPathComponent:@"Preset.plist"];
    NSData *plistData = [NSPropertyListSerialization dataFromPropertyList: preset
                                                                   format:NSPropertyListXMLFormat_v1_0 errorDescription:&error];
    if(plistData) {
        [plistData writeToFile:plistPath atomically:YES];
    }
    else {
        NSLog(@"Error : %@",error);
    }

}

#pragma mark - data source
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return MAX([_presets allKeys].count, 12);
}

// Row display. Implementers should *always* try to reuse cells by setting each cell's reuseIdentifier and querying for available reusable cells with dequeueReusableCellWithIdentifier:
// Cell gets various attributes set automatically based on table (separators) and data source (accessory views, editing controls)

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    [cell setBackgroundColor:[UIColor blackColor]];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.font = [UIFont fontWithName:@"Courier-Bold" size:16];
    if (indexPath.row < [_presets allKeys].count) {
        NSString *cellLabel = [[_presets allKeys] objectAtIndex:indexPath.row];
        cell.textLabel.text = cellLabel;
    } else {
        cell.textLabel.text = @"None";
    }
    
    return cell;
}

#pragma mark - table view zone
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    selectedRow = indexPath.row;
}

#pragma mark - delete zone
- (IBAction)delete:(id)sender {
    if (selectedRow >= 0 && selectedRow < [_presets allKeys].count) {
        NSString *key = [[_presets allKeys] objectAtIndex:selectedRow];
        [_presets removeObjectForKey:key];
        [self writeToFile:_presets];
        [_presetTable reloadData];
        selectedRow = -1;
    }
}


#pragma mark - done zone

- (IBAction)done:(id)sender {
    [self.delegate getPresets:_presets from:self atRow:selectedRow];
    //[self dismissViewControllerAnimated:YES completion:nil];
}

@end
