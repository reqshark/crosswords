//
//  DetailViewController.h
//  Crosswords
//
//  Created by Mark Alldritt on 2/1/2014.
//  Copyright (c) 2014 Late Night Software Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PuzzleHelper.h"
#import "GridView.h"


@interface DetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) PuzzleHelper* puzzle;

@property (weak, nonatomic) IBOutlet UILabel *authorView;
@property (weak, nonatomic) IBOutlet UILabel *copyrightView;
@property (weak, nonatomic) IBOutlet UILabel *notesView;
@property (weak, nonatomic) IBOutlet UISwitch *showAnswersView;
@property (weak, nonatomic) IBOutlet GridView *gridView;

- (IBAction)toggleShowAnswers:(id)sender;

@end
