//
//  AGEmojiKeyboardView.m
//  AGEmojiKeyboard
//
//  Created by Ayush on 09/05/13.
//  Copyright (c) 2013 Ayush. All rights reserved.
//

#import "AGEmojiKeyBoardView.h"
#import "AGEmojiPageView.h"

static const CGFloat ButtonWidth = 45;
static const CGFloat ButtonHeight = 37;

static const NSUInteger DefaultRecentEmojisMaintainedCount = 50;

static NSString *const segmentRecentName = @"Recent";
NSString *const RecentUsedEmojiCharactersKey = @"RecentUsedEmojiCharactersKey";

@interface AGEmojiKeyboardView () <UIScrollViewDelegate, AGEmojiPageViewDelegate, UITabBarDelegate>

@property (nonatomic) UISegmentedControl *segmentsBar;
@property (nonatomic) UITabBar *tabBar;
@property (nonatomic) UIScrollView *emojiPagesScrollView;
@property (nonatomic) NSDictionary *emojis;
@property (nonatomic) NSMutableArray *pageViews;
@property (nonatomic) NSString *category;
@property (nonatomic) NSInteger currentPage;
@property (nonatomic) NSInteger numberOfPages;
@property (nonatomic) AGEmojiKeyboardViewCategoryImage previousCategory;

@end

@implementation AGEmojiKeyboardView

- (NSDictionary *)emojis {
    if (!_emojis) {
        NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"EmojisList"
                                                              ofType:@"plist"];
        _emojis = [[NSDictionary dictionaryWithContentsOfFile:plistPath] copy];
    }
    return _emojis;
}

- (NSArray *)categoryList {
    return @[@"Keyboard", @"Recent", @"People", @"Nature", @"Food", @"Activity", @"Travel", @"Objects", @"Symbols", @"Flags", @"Delete"];
}

- (NSString *)categoryNameAtIndex:(NSUInteger)index {
    if (index < self.categoryList.count) {
        return self.categoryList[index];
    }
    
    return @"";
}

- (AGEmojiKeyboardViewCategoryImage)defaultSelectedCategory {
    if ([self.dataSource respondsToSelector:@selector(defaultCategoryForEmojiKeyboardView:)]) {
        return [self.dataSource defaultCategoryForEmojiKeyboardView:self];
    }
    return AGEmojiKeyboardViewCategoryImageRecent;
}

- (NSUInteger)recentEmojisMaintainedCount {
    if ([self.dataSource respondsToSelector:@selector(recentEmojisMaintainedCountForEmojiKeyboardView:)]) {
        return [self.dataSource recentEmojisMaintainedCountForEmojiKeyboardView:self];
    }
    return DefaultRecentEmojisMaintainedCount;
}

- (NSArray *)imagesForCategory {
    static NSMutableArray *array;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        array = [NSMutableArray array];
        for (AGEmojiKeyboardViewCategoryImage i = AGEmojiKeyboardViewCategoryImageKeyboard;
             i <= AGEmojiKeyboardViewCategoryImageDelete;
             ++i) {
            [array addObject:[self.dataSource emojiKeyboardView:self imageForCategory:i]];
        }
    });
    return array;
}

// recent emojis are backed in NSUserDefaults to save them across app restarts.
- (NSMutableArray *)recentEmojis {
    NSArray *emojis = [[NSUserDefaults standardUserDefaults] arrayForKey:RecentUsedEmojiCharactersKey];
    NSMutableArray *recentEmojis = [emojis mutableCopy];
    if (recentEmojis == nil) {
        recentEmojis = [NSMutableArray array];
    }
    return recentEmojis;
}

- (void)setRecentEmojis:(NSMutableArray *)recentEmojis {
    // remove emojis if they cross the cache maintained limit
    if ([recentEmojis count] > self.recentEmojisMaintainedCount) {
        NSRange indexRange = NSMakeRange(self.recentEmojisMaintainedCount,
                                         [recentEmojis count] - self.recentEmojisMaintainedCount);
        NSIndexSet *indexesToBeRemoved = [NSIndexSet indexSetWithIndexesInRange:indexRange];
        [recentEmojis removeObjectsAtIndexes:indexesToBeRemoved];
    }
    [[NSUserDefaults standardUserDefaults] setObject:recentEmojis forKey:RecentUsedEmojiCharactersKey];
}

-(void)setupTabBarItems {
    
    NSMutableArray *tabBarItems = [NSMutableArray array];
    for(int i = 0; i < self.imagesForCategory.count; i++) {
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"" image:self.imagesForCategory[i] tag:i];
        item.imageInsets = UIEdgeInsetsMake(5, 0, -5, 0);
        [tabBarItems addObject:item];
    }
    [self.tabBar setItems:tabBarItems];
}

- (instancetype)initWithFrame:(CGRect)frame dataSource:(id<AGEmojiKeyboardViewDataSource>)dataSource {
    self = [super initWithFrame:frame];
    if (self) {
        // initialize category
        
        _dataSource = dataSource;
        
        self.category = [self categoryNameAtIndex:self.defaultSelectedCategory];
        self.previousCategory = AGEmojiKeyboardViewCategoryImageRecent;
        
        self.tabBar = [[UITabBar alloc] init];
        self.tabBar.delegate = self;
        self.tabBar.backgroundColor = [UIColor whiteColor];
        self.tabBar.layer.borderColor = [UIColor whiteColor].CGColor;
        self.tabBar.clipsToBounds = YES;
        self.tabBar.tintColor = [UIColor darkGrayColor];
        UIImage * selectedBackground = [[self.dataSource selectedBackgroundImageForEmojiKeyboardView:self] imageWithAlignmentRectInsets:UIEdgeInsetsMake(0, -2, 0, 0)];
        [self.tabBar setSelectionIndicatorImage:selectedBackground];
        [self setupTabBarItems];
        [self addSubview:self.tabBar];
        
        self.currentPage = 0;
        
        CGRect scrollViewFrame = CGRectMake(0,
                                            0,
                                            CGRectGetWidth(self.bounds),
                                            CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds));
        self.emojiPagesScrollView = [[UIScrollView alloc] initWithFrame:scrollViewFrame];
        self.emojiPagesScrollView.pagingEnabled = NO;
        self.emojiPagesScrollView.showsHorizontalScrollIndicator = NO;
        self.emojiPagesScrollView.showsVerticalScrollIndicator = NO;
        self.emojiPagesScrollView.delegate = self;
        
        [self addSubview:self.emojiPagesScrollView];
    }
    return self;
}

- (UIImage *)imageWithColor:(UIColor *)color {
    CGRect rect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextSetFillColorWithColor(context, [color CGColor]);
    CGContextFillRect(context, rect);
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return image;
}

- (void)layoutSubviews {
    NSUInteger numberOfPages = [self numberOfPagesForCategory:self.category
                                                  inFrameSize:CGSizeMake(CGRectGetWidth(self.bounds),
                                                                         CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds))];
    
    NSInteger currentPage = (self.currentPage > numberOfPages) ? numberOfPages : self.currentPage;
    
    // if (currentPage > numberOfPages) it is set implicitly to max pageNumber available
    self.numberOfPages = numberOfPages;
    self.tabBar.frame = CGRectMake(0, CGRectGetHeight(self.bounds)-CGRectGetHeight(self.tabBar.bounds), CGRectGetWidth(self.bounds), 30);
    
    self.emojiPagesScrollView.frame = CGRectMake(0,
                                                 0,
                                                 CGRectGetWidth(self.bounds),
                                                 CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds));
    [self.emojiPagesScrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.emojiPagesScrollView.contentOffset = CGPointMake(CGRectGetWidth(self.emojiPagesScrollView.bounds) * currentPage, 0);
    self.emojiPagesScrollView.contentSize = CGSizeMake(CGRectGetWidth(self.emojiPagesScrollView.bounds) * numberOfPages,
                                                       CGRectGetHeight(self.emojiPagesScrollView.bounds));
    [self purgePageViews];
    self.pageViews = [NSMutableArray array];
    [self setPage:currentPage];
}

// Track the contentOffset of the scroll view, and when it passes the mid
// point of the current view’s width, the views are reconfigured.
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    CGFloat pageWidth = CGRectGetWidth(scrollView.frame);
    NSInteger newPageNumber = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    if (self.currentPage == newPageNumber) {
        return;
    }
    self.currentPage = newPageNumber;
    [self setPage:self.currentPage];
}

#pragma mark change a page on scrollView

// Check if setting pageView for an index is required
- (BOOL)requireToSetPageViewForIndex:(NSUInteger)index {
    if (index >= self.numberOfPages) {
        return NO;
    }
    for (AGEmojiPageView *page in self.pageViews) {
        if ((page.frame.origin.x / CGRectGetWidth(self.emojiPagesScrollView.bounds)) == index) {
            return NO;
        }
    }
    return YES;
}

// Create a pageView and add it to the scroll view.
- (AGEmojiPageView *)synthesizeEmojiPageView {
    NSUInteger rows = [self numberOfRowsForFrameSize:self.emojiPagesScrollView.bounds.size];
    NSUInteger columns = [self numberOfColumnsForFrameSize:self.emojiPagesScrollView.bounds.size];
    CGRect pageViewFrame = CGRectMake(0,
                                      0,
                                      CGRectGetWidth(self.emojiPagesScrollView.bounds),
                                      CGRectGetHeight(self.emojiPagesScrollView.bounds));
    AGEmojiPageView *pageView = [[AGEmojiPageView alloc] initWithFrame: pageViewFrame
                                                  backSpaceButtonImage:[self.dataSource selectedBackgroundImageForEmojiKeyboardView:self]
                                                            buttonSize:CGSizeMake(ButtonWidth, ButtonHeight)
                                                                  rows:rows
                                                               columns:columns];
    pageView.delegate = self;
    [self.pageViews addObject:pageView];
    [self.emojiPagesScrollView addSubview:pageView];
    return pageView;
}

// return a pageView that can be used in the current scrollView.
// look for an available pageView in current pageView-s on scrollView.
// If all are in use i.e. are of current page or neighbours
// of current page, we create a new one

- (AGEmojiPageView *)usableEmojiPageView {
    AGEmojiPageView *pageView = nil;
    for (AGEmojiPageView *page in self.pageViews) {
        NSUInteger pageNumber = page.frame.origin.x / CGRectGetWidth(self.emojiPagesScrollView.bounds);
        if (abs((int)(pageNumber - self.currentPage)) > 1) {
            pageView = page;
            break;
        }
    }
    if (!pageView) {
        pageView = [self synthesizeEmojiPageView];
    }
    return pageView;
}

// Set emoji page view for given index.
- (void)setEmojiPageViewInScrollView:(UIScrollView *)scrollView atIndex:(NSUInteger)index {
    
    if (![self requireToSetPageViewForIndex:index]) {
        return;
    }
    
    AGEmojiPageView *pageView = [self usableEmojiPageView];
    
    NSUInteger rows = [self numberOfRowsForFrameSize:scrollView.bounds.size];
    NSUInteger columns = [self numberOfColumnsForFrameSize:scrollView.bounds.size];
    NSUInteger startingIndex = index * (rows * columns);
    NSUInteger endingIndex = (index + 1) * (rows * columns);
    NSMutableArray *buttonTexts = [self emojiTextsForCategory:self.category
                                                    fromIndex:startingIndex
                                                      toIndex:endingIndex];
    [pageView setButtonTexts:buttonTexts];
    pageView.frame = CGRectMake(index * CGRectGetWidth(scrollView.bounds),
                                0,
                                CGRectGetWidth(scrollView.bounds),
                                CGRectGetHeight(scrollView.bounds));
}

// Set the current page.
// sets neightbouring pages too, as they are viewable by part scrolling.
- (void)setPage:(NSInteger)page {
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:page - 1];
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:page];
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:page + 1];
}

- (void)purgePageViews {
    for (AGEmojiPageView *page in self.pageViews) {
        page.delegate = nil;
    }
    self.pageViews = nil;
}

#pragma mark data methods

- (NSUInteger)numberOfColumnsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.width / ButtonWidth);
}

- (NSUInteger)numberOfRowsForFrameSize:(CGSize)frameSize {
    return (NSUInteger)floor(frameSize.height / ButtonHeight);
}

- (NSArray *)emojiListForCategory:(NSString *)category {
    if ([category isEqualToString:segmentRecentName]) {
        return [self recentEmojis];
    }
    return [self.emojis objectForKey:category];
}

- (NSUInteger)totalNumberOfPages {
    NSInteger *total = 0;
    CGSize frameSize = CGSizeMake(CGRectGetWidth(self.bounds),
                                  CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds));
    
    for (NSString *categoryName in self.categoryList) {
        total += [self numberOfPagesForCategory:categoryName inFrameSize:frameSize];
    }
    
    return total;
}

// for a given frame size of scroll view, return the number of pages
// required to show all the emojis for a category
- (NSUInteger)numberOfPagesForCategory:(NSString *)category inFrameSize:(CGSize)frameSize {
    
    if ([category isEqualToString:segmentRecentName]) {
        return 1;
    }
    
    NSUInteger emojiCount = [[self emojiListForCategory:category] count];
    NSUInteger numberOfRows = [self numberOfRowsForFrameSize:frameSize];
    NSUInteger numberOfColumns = [self numberOfColumnsForFrameSize:frameSize];
    NSUInteger numberOfEmojisOnAPage = (numberOfRows * numberOfColumns);
    
    NSUInteger numberOfPages = (NSUInteger)ceil((float)emojiCount / numberOfEmojisOnAPage);
    return numberOfPages;
}

// return the emojis for a category, given a staring and an ending index
- (NSMutableArray *)emojiTextsForCategory:(NSString *)category
                                fromIndex:(NSUInteger)start
                                  toIndex:(NSUInteger)end {
    NSArray *emojis = [self emojiListForCategory:category];
    end = ([emojis count] > end)? end : [emojis count];
    NSIndexSet *index = [[NSIndexSet alloc] initWithIndexesInRange:NSMakeRange(start, end-start)];
    return [[emojis objectsAtIndexes:index] mutableCopy];
}

#pragma mark EmojiPageViewDelegate

- (void)setInRecentsEmoji:(NSString *)emoji {
    NSAssert(emoji != nil, @"Emoji can't be nil");
    
    NSMutableArray *recentEmojis = [self recentEmojis];
    for (int i = 0; i < [recentEmojis count]; ++i) {
        if ([recentEmojis[i] isEqualToString:emoji]) {
            [recentEmojis removeObjectAtIndex:i];
        }
    }
    [recentEmojis insertObject:emoji atIndex:0];
    [self setRecentEmojis:recentEmojis];
}

// add the emoji to recents
- (void)emojiPageView:(AGEmojiPageView *)emojiPageView didUseEmoji:(NSString *)emoji {
    [self setInRecentsEmoji:emoji];
    [self.delegate emojiKeyBoardView:self didUseEmoji:emoji];
}

- (void)emojiPageViewDidPressBackSpace:(AGEmojiPageView *)emojiPageView {
    [self.delegate emojiKeyBoardViewDidPressBackSpace:self];
}

#pragma mark UITabBarDelegate
- (void) tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    NSInteger index = item.tag;
    
    if (index == 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"BackToKeyboardSegmentPressed" object:self];
        index = self.previousCategory;
    } else if (index == 10) {
        [self.dataSource emojiKeyBoardViewDidPressDeleteButton:self];
        index = self.previousCategory;
    }
    
    self.category = [self categoryNameAtIndex:index];
    [self.tabBar setSelectedItem:self.tabBar.items[index]];
    self.currentPage = 0;
    [self setNeedsLayout];
    self.previousCategory = index;
}

@end
