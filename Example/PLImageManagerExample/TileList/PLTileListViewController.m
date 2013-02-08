//
// Created by antoni on 2/8/13.
//
// To change the template use AppCode | Preferences | File Templates.
//


#import "PLTileListViewController.h"
#import "PLAppDelegate.h"
#import "PLTileManager.h"


@implementation PLTileListViewController {

}

NSUInteger const tileYMin = 326;
NSUInteger const tileYMax = 351;
NSUInteger const tileXMin = 551;
NSUInteger const tileXMax = 580;

- (id)init {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {

    }

    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 100;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return tileYMax - tileYMin;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return tileXMax - tileXMin;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"y: %d", tileYMin + section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"TileCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }

    NSUInteger const hash = [indexPath hash];
    cell.tag = hash;

    cell.textLabel.text = [NSString stringWithFormat:@"y: %d x: %d", tileYMin + indexPath.section, tileXMin + indexPath.row];

    cell.imageView.backgroundColor = [UIColor blackColor];
    cell.imageView.image = nil;

    [[PLAppDelegate appDelegate].tileManager tileForZoomLevel:10 tileX:tileXMin + indexPath.row
                                                        tileY:tileYMin + indexPath.section
                                                     callback:^(UIImage *image, NSUInteger zoom, NSInteger tileX, NSInteger tileY) {
                                                         if (cell.tag == hash) {
                                                             cell.imageView.image = image;
                                                             [cell setNeedsLayout];
                                                         }
                                                     }];

    return cell;
}

@end