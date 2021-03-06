//
//  PuzzleHelper.m
//  Crosswords
//
//  Created by Mark Alldritt on 2/6/2014.
//  Copyright (c) 2014 Late Night Software Ltd. All rights reserved.
//
//
//  Puzzles are stored in NSDictionary instances, but sometimes some logic is needed to pull out useful
//  information.  This object pairs with the puzzel NSDictionary to provide useful accessors

#import "PuzzleHelper.h"
#import "GTMNSString+HTML.h"


@interface PuzzleHelper ()

@property (strong, nonatomic) NSString* filename;

@end

@implementation PuzzleHelper

@synthesize filename = mFilename;
@synthesize puzzle = mPuzzle;
@synthesize cluesAcross = mCluesAcross;
@synthesize cluesDown = mCluesDown;
@synthesize title = mTitle;
@synthesize author = mAuthor;
@synthesize editor = mEditor;
@synthesize publisher = mPublisher;
@synthesize copyright = mCopyright;
@synthesize notes = mNotes;
@synthesize playerGrid = mPlayerGrid;

- (instancetype)initWithPuzzle:(NSDictionary *)puzzle filename:(NSString*) filename {
    //  We need a unique ID for the puzzle.  The contents of the puzzle don't guarentee this, so I'm using the file name.  This will
    //  probably not work in the long run, but it gets me moving forward.
    NSParameterAssert([puzzle isKindOfClass:[NSDictionary class]]);

    if ((self = [super init])) {
        mPuzzle = puzzle;
        mFilename = filename;
    }
    
    return self;
}

- (NSDictionary*)_makeDictionaryForClues:(NSArray*) clues answers:(NSArray*) answers across:(BOOL) across {
    NSRegularExpression* regEx = [NSRegularExpression regularExpressionWithPattern:@"^(\\d+)\\.\\s*(.*)$" options:0 error:nil];
    NSMutableDictionary* result = [NSMutableDictionary dictionary];
    NSArray* gridNums = self.puzzle[@"gridnums"];
    NSInteger rows = self.rows;
    NSInteger cols = self.columns;
    NSInteger i = 0;
    
    for (NSString* aClue in clues) {
        //  Clues are expressed as strings: '1. clue text'.  Here we break this up into a number, and the text
        NSTextCheckingResult* match = [regEx firstMatchInString:aClue options:0 range:NSMakeRange(0, aClue.length)];
        
        NSAssert(match.numberOfRanges == 3, @"invalue clue string"); // make the code defensive for this in future
        
        NSInteger clueNo = [[aClue substringWithRange:[match rangeAtIndex:1]] integerValue];
        NSString* clue = [[aClue substringWithRange:[match rangeAtIndex:2]] gtm_stringByUnescapingFromHTML];
        NSString* answer = [answers[i] gtm_stringByUnescapingFromHTML];
        NSInteger row = -1;
        NSInteger col = -1;
        
        NSUInteger j = 0;
        for (NSNumber* aGridNum in gridNums) {
            if (aGridNum.integerValue == clueNo) {
                row = j / cols;
                col = j % cols;
                break;
            }
            ++j;
        }
        
        NSAssert1(row >= 0, @"gridnum (%d) row not found", (int)clueNo);
        NSAssert2(row < rows, @"gridnum row (%d) too big (%d)!", (int)row, (int)rows);
        NSAssert1(col >= 0, @"gridnum (%d)column not found", (int)clueNo);
        NSAssert2(col < cols, @"gridnum column (%d) too big (%d)!", (int)col, (int)cols);
        
        CGRect area = across ? CGRectMake(col, row, answer.length, 1.0) : CGRectMake(col, row, 1.0, answer.length);

        result[@(clueNo)] = @{@"gridnum": @(clueNo), @"clue": clue, @"answer" : answer, @"row" : @(row), @"col" : @(col), @"across" : @(across), @"area" : [NSValue valueWithCGRect:area]};
        ++i;
    }
    
    return result.copy; // return a non-mutable version of the data;
}

- (NSDictionary*)cluesAcross {
    //  The problem with the JSON format we are using is that clues are delivered as an array of strings.  This code turns those
    //  strings into a dictionary keyed by clue number.  Also, each dictionary entry is a dictionary of useful information:
    //  - gridnum
    //  - clue
    //  - answer
    //  - row
    //  - column
    //  - accros
    //
    //  This is all done in a brute force fashion, but the data sets are not that large so I don't think we are going to
    //  experience too much of a performance hit.  If this becomes a problem, we can return here in future and improve the
    //  approach.
    
    if (!mCluesAcross)
        mCluesAcross = [self _makeDictionaryForClues:[self.puzzle valueForKeyPath:@"clues.across"]
                                             answers:[self.puzzle valueForKeyPath:@"answers.across"]
                                              across:YES];
    return mCluesAcross;
}

- (NSDictionary*)cluesDown {
    //  The problem with the JSON format we are using is that clues are delivered as an array of strings.  This code turns those
    //  strings into a dictionary keyed by clue number.  Also, each dictionary entry is a dictionary of useful information:
    //  - gridnum
    //  - clue
    //  - answer
    //  - row
    //  - column
    //  - accros
    //
    //  This is all done in a brute force fashion, but the data sets are not that large so I don't think we are going to
    //  experience too much of a performance hit.  If this becomes a problem, we can return here in future and improve the
    //  approach.
    
    if (!mCluesDown)
        mCluesDown = [self _makeDictionaryForClues:[self.puzzle valueForKeyPath:@"clues.down"]
                                           answers:[self.puzzle valueForKeyPath:@"answers.down"]
                                            across:NO];
    return mCluesDown;
}

- (NSArray*)cluesAtRow:(NSInteger)row column:(NSInteger)column {
    NSParameterAssert(row >= 0 && row < self.rows);
    NSParameterAssert(column >= 0 && column < self.columns);
    
    //  Given a row & column, return the clue that begins at that location on the grid.
    NSInteger cols = self.columns;
    NSInteger index = row * cols + column;
    NSNumber* clueNo = self.puzzle[@"gridnums"][index];
    
    if (clueNo > 0) {
        NSDictionary* acrossClue = self.cluesAcross[clueNo];
        NSDictionary* downClue = self.cluesDown[clueNo];
        
        if (acrossClue && downClue)
            return @[acrossClue, downClue];
        else if (acrossClue)
            return @[acrossClue];
        else if (downClue)
            return @[downClue];
        else
            return nil;
    }
    return nil;
}

- (NSDictionary*)bestClueForRow:(NSInteger)row column:(NSInteger)column {
    //  This routine differs from cluesAtRow:column: in that the row and column need not be the explicit start of a
    //  clue.  This routine looks around the row & column specified for the "best" clue.  For now, "best" is defined
    //  as the clue that begines at the cell "closest" to the row & column specified.  If there is a tie, its the
    //  first one found.
    //
    //  We can make this smarter if the wrong thing happens during play.  I intend to use this to find the clue the
    //  user is tapping on.
    
    //  Start by seeing if the we can get a direct hit on the beginning on a clue.
    NSDictionary* clue = [self cluesAtRow:row column:column][0];
    
    if (!clue) {
        //  Nope.  Hunt through all the clues for a clue that intersects the row & column specified.  For
        //  each intersecting clue, calculate a "distance" from the row & column specified.  With the distance, we
        //  can then look for hits with the shortest distance.
        
        NSInteger distance = NSIntegerMax;
        
        for (NSDictionary* aClue in self.cluesAcross.allValues) {
            if (row == [aClue[@"row"] integerValue] &&
                column >= [aClue[@"col"] integerValue] &&
                column < [aClue[@"col"] integerValue] + [aClue[@"answer"] length]) {
                NSUInteger aClueDistance = MAX(ABS([aClue[@"col"] integerValue] - column), ABS([aClue[@"row"] integerValue] - row));
                
                if (aClueDistance < distance) {
                    distance = aClueDistance;
                    clue = aClue;
                }
            }
        }

        for (NSDictionary* aClue in self.cluesDown.allValues) {
            if (column == [aClue[@"col"] integerValue] &&
                row >= [aClue[@"row"] integerValue] &&
                row < [aClue[@"row"] integerValue] + [aClue[@"answer"] length]) {
                NSUInteger aClueDistance = MAX(ABS([aClue[@"col"] integerValue] - column), ABS([aClue[@"row"] integerValue] - row));
                
                if (aClueDistance < distance) {
                    distance = aClueDistance;
                    clue = aClue;
                }
            }
        }
    }
    
    return clue;
}

- (NSArray*)cluesIntersectingClue:(NSDictionary*) clue {
    if (!clue)
        return nil;
    NSAssert(clue[@"area"], @"This does not appear to be a clue dictionary");

    //  Determine all the clues that intersect with the answer for a clue.  This is brute force, but for now, its good enough.
    
    CGRect clueArea = [clue[@"area"] CGRectValue];
    NSMutableArray* result = nil;
    
    for (NSDictionary* aClue in self.cluesAcross.allValues) {
        if (CGRectIntersectsRect(clueArea, [aClue[@"area"] CGRectValue])) {
            if (result)
                [result addObject:aClue];
            else
                result = [NSMutableArray arrayWithObject:aClue];
        }
    }
    for (NSDictionary* aClue in self.cluesDown.allValues) {
        if (CGRectIntersectsRect(clueArea, [aClue[@"area"] CGRectValue])) {
            if (result)
                [result addObject:aClue];
            else
                result = [NSMutableArray arrayWithObject:aClue];
        }
    }
    
    return result.copy; // return a non-mutable version...
}

- (NSString*) title {
    if (!mTitle) {
        mTitle = self.puzzle[@"title"];
        if ([mTitle isEqual:[NSNull null]] || mTitle.length == 0)
            mTitle = @"Untitled";
        else
            mTitle = [[mTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mTitle;
}

- (NSString*) author {
    if (!mAuthor) {
        mAuthor = self.puzzle[@"author"];
        if ([mAuthor isEqual:[NSNull null]] || mAuthor.length == 0)
            mAuthor = @"Author unknown";
        else
            mAuthor = [[mAuthor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mAuthor;
}

- (BOOL)hasAuthor {
    NSString* author = self.puzzle[@"author"];
    
    return [author isEqual:[NSNull null]] || author.length == 0 ? NO : YES;
}

- (NSString*) editor {
    if (!mEditor) {
        mEditor = self.puzzle[@"editor"];
        if ([mEditor isEqual:[NSNull null]] || mEditor.length == 0)
            mEditor = @"";
        else
            mEditor = [[mEditor stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mEditor;
}

- (NSString*) publisher {
    if (!mPublisher) {
        mPublisher = self.puzzle[@"publisher"];
        if ([mPublisher isEqual:[NSNull null]] || mPublisher.length == 0)
            mPublisher = @"Unknown publisher";
        else
            mPublisher = [[mPublisher stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mPublisher;
}

- (NSString*) copyright {
    if (!mCopyright) {
        mCopyright = self.puzzle[@"copyright"];
        if ([mCopyright isEqual:[NSNull null]] || mCopyright.length == 0)
            mCopyright = @"Unknown";
        else
            mCopyright = [[mCopyright stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mCopyright;
}

- (NSString*) notes {
    if (!mNotes) {
        mNotes = self.puzzle[@"jnotes"];
        if ([mNotes isEqual:[NSNull null]] || mNotes.length == 0)
            mNotes = @"";
        else
            mNotes = [[mNotes stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] gtm_stringByUnescapingFromHTML];
    }
    return mNotes;
}

- (NSUInteger)rows { return [[self.puzzle valueForKeyPath:@"size.rows"] integerValue]; }
- (NSUInteger)columns { return [[self.puzzle valueForKeyPath:@"size.cols"] integerValue]; }

- (NSArray*) playerGrid {
    if (!mPlayerGrid) {
        NSMutableArray* grid = [NSMutableArray arrayWithArray:self.puzzle[@"grid"]];
        NSUInteger length = grid.count;
        
        for (NSUInteger i = 0; i < length; ++i) {
            if (![grid[i] isEqualToString:@"."])
                grid[i] = @"";
        }
        mPlayerGrid = grid.copy; // non-mutable copy.
                                 // In time, I'm going to have to save the player's answers which will require that I alter this
                                 // array.
    }
    return mPlayerGrid;
}

@end
