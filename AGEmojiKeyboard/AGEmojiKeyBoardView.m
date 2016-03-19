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
@property (nonatomic) NSMutableDictionary *startingPages;
@property (nonatomic) AGEmojiKeyboardViewCategoryImage previousCategory;
@property (nonatomic) NSTimer *timer;
@property (nonatomic) int categoryIndex;
@property (nonatomic) UILabel *categoryLabel;
@property (nonatomic) UIView *categoryLabelView;
@property (nonatomic) UIView *topSection;
@property (nonatomic) UIView *bottomSection;

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
    
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"ABC" image:nil tag:0];
    [item setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"OpenSans-Semibold" size:12]} forState:UIControlStateNormal];
    [item setTitlePositionAdjustment:UIOffsetMake(4, -12)];
    [tabBarItems addObject:item];
    
    
    for(int i = 1; i < self.imagesForCategory.count; i++) {
        UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"" image:self.imagesForCategory[i] tag:i];
        
        if (i == self.imagesForCategory.count - 1) {
            item.imageInsets = UIEdgeInsetsMake(5, -5, -5, 5);
        } else {
            item.imageInsets = UIEdgeInsetsMake(5, 0, -5, 0);
        }
        
        [tabBarItems addObject:item];
    }
    
    [self.tabBar setItems:tabBarItems];
}

- (instancetype)initWithFrame:(CGRect)frame dataSource:(id<AGEmojiKeyboardViewDataSource>)dataSource {
    self = [super initWithFrame:frame];
    if (self) {
        // initialize category
        
        self.startingPages = [NSMutableDictionary dictionary];
        self.categoryIndex = 0;
        _dataSource = dataSource;
        
        self.categoryLabelView = [[UIView alloc] init];
        self.categoryLabelView.backgroundColor = [UIColor whiteColor];
        self.categoryLabelView.layer.borderColor = [UIColor darkGrayColor].CGColor;
        self.categoryLabelView.layer.borderWidth = 0.2;
        
        self.categoryLabel = [[UILabel alloc] init];
        self.categoryLabel.text = [[self categoryNameAtIndex:self.defaultSelectedCategory] uppercaseString];
        self.categoryLabel.font = [UIFont fontWithName:@"OpenSans-Semibold" size:12];
        self.categoryLabel.textColor = [UIColor lightGrayColor];
        
        self.topSection = [[UIView alloc] init];
        self.topSection.backgroundColor = [UIColor lightGrayColor];
        
        self.bottomSection = [[UIView alloc] init];
        self.bottomSection.backgroundColor = [UIColor lightGrayColor];
        
        
        self.category = [self categoryNameAtIndex:self.defaultSelectedCategory];
        self.previousCategory = AGEmojiKeyboardViewCategoryImageRecent;
        
        self.tabBar = [[UITabBar alloc] init];
        self.tabBar.delegate = self;
        self.tabBar.backgroundColor = [UIColor whiteColor];
        self.tabBar.tintColor = [UIColor darkGrayColor];
        self.tabBar.clipsToBounds = YES;
        UIImage * selectedBackground = [[self.dataSource selectedBackgroundImageForEmojiKeyboardView:self] imageWithAlignmentRectInsets:UIEdgeInsetsMake(0, -5, 0, 0)];
        [self.tabBar setSelectionIndicatorImage:selectedBackground];
        [self setupTabBarItems];
        [self.tabBar setSelectedItem:self.tabBar.items[self.previousCategory]];
        
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
        
        [self.categoryLabelView addSubview:self.categoryLabel];
        [self addSubview:self.categoryLabelView];
        [self addSubview:self.topSection];
        [self addSubview:self.bottomSection];
        [self addSubview:self.emojiPagesScrollView];
        [self addSubview:self.tabBar];
    }
    return self;
}

- (void)layoutSubviews {
    
    NSUInteger numberOfPages = [self totalNumberOfPages];
    NSInteger currentPage = (self.currentPage > numberOfPages) ? numberOfPages : self.currentPage;
    
    // if (currentPage > numberOfPages) it is set implicitly to max pageNumber available
    self.numberOfPages = numberOfPages;
    self.tabBar.frame = CGRectMake(0, CGRectGetHeight(self.bounds)-CGRectGetHeight(self.tabBar.bounds), CGRectGetWidth(self.bounds), 40);
    
    self.categoryLabelView.frame = CGRectMake(0, 0, CGRectGetWidth(self.bounds), 30);
    self.categoryLabel.frame = CGRectMake(12, 0, CGRectGetWidth(self.bounds), 30);
    self.topSection.frame = CGRectMake(0, CGRectGetHeight(self.categoryLabelView.bounds) - 0.6, CGRectGetWidth(self.bounds), 0.6);
    self.bottomSection.frame = CGRectMake(0, CGRectGetHeight(self.bounds)-CGRectGetHeight(self.tabBar.bounds) - 0.6, CGRectGetWidth(self.bounds), 0.6);
    
    self.emojiPagesScrollView.frame = CGRectMake(0,
                                                 CGRectGetHeight(self.categoryLabel.bounds),
                                                 CGRectGetWidth(self.bounds),
                                                 CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds)-CGRectGetHeight(self.categoryLabel.bounds));
    [self.emojiPagesScrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.emojiPagesScrollView.contentOffset = CGPointMake(CGRectGetWidth(self.emojiPagesScrollView.bounds) * currentPage, 0);
    self.emojiPagesScrollView.contentSize = CGSizeMake(CGRectGetWidth(self.emojiPagesScrollView.bounds) * numberOfPages,
                                                       CGRectGetHeight(self.emojiPagesScrollView.bounds));
    [self purgePageViews];
    self.pageViews = [NSMutableArray array];
    [self setPage:currentPage];
}

- (void)setPage:(NSInteger)page {
    
    NSString *categoryPage = [self categoryNameAtIndex:[self findSectionForPage:page-1]];
    NSInteger relativeIndex = page - [self.startingPages[categoryPage] intValue]-1;
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:relativeIndex atFrameIndex:page - 1];
    
    relativeIndex = page - [self.startingPages[self.category] intValue];
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:relativeIndex atFrameIndex:page];
    
    categoryPage = [self categoryNameAtIndex:[self findSectionForPage:page+1]];
    relativeIndex = abs([self.startingPages[categoryPage] intValue] - (page+1));
    [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:relativeIndex atFrameIndex:page + 1];
    
    self.category = [self categoryNameAtIndex:page];
}

- (NSInteger)findSectionForPage:(NSInteger)page {
    
    NSInteger curNumber = 0;
    for (int i = 1; i < self.categoryList.count-1; i++)  {
        NSInteger startingPage = [self.startingPages[[self categoryNameAtIndex:i]] intValue];
        if (startingPage <= page) {
            curNumber = i;
        } else {
            return curNumber;
        }
    }
    return curNumber;
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
    NSUInteger index = [self findSectionForPage:self.currentPage];
    [self.tabBar setSelectedItem:self.tabBar.items[index]];
    self.previousCategory = index;
    self.category = [self categoryNameAtIndex:index];
    self.categoryLabel.text = [self.category uppercaseString];
    [self setPage:self.currentPage];
}

#pragma mark change a page on scrollView

// Check if setting pageView for an index is required
- (BOOL)requireToSetPageViewForIndex:(NSInteger)index {
    if (index >= self.numberOfPages || index < 0) {
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
- (void)setEmojiPageViewInScrollView:(UIScrollView *)scrollView atIndex:(NSInteger)index atFrameIndex:(NSInteger)frameIndex {
    
    if (![self requireToSetPageViewForIndex:frameIndex]) {
        return;
    }
    
    self.category = [self categoryNameAtIndex:[self findSectionForPage:frameIndex]];
    
    AGEmojiPageView *pageView = [self usableEmojiPageView];
    NSInteger rows = [self numberOfRowsForFrameSize:scrollView.bounds.size];
    NSInteger columns = [self numberOfColumnsForFrameSize:scrollView.bounds.size];
    NSInteger startingIndex = index * (rows * columns);
    NSInteger endingIndex = (index + 1) * (rows * columns);
    NSMutableArray *buttonTexts = [self emojiTextsForCategory:self.category
                                                    fromIndex:startingIndex
                                                      toIndex:endingIndex];
    [pageView setButtonTexts:buttonTexts];
    pageView.frame = CGRectMake(frameIndex * CGRectGetWidth(scrollView.bounds),
                                0,
                                CGRectGetWidth(scrollView.bounds),
                                CGRectGetHeight(scrollView.bounds));
    
    self.category = [self categoryNameAtIndex:self.previousCategory];
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
    return 4;
}

- (NSArray *)emojiListForCategory:(NSString *)category {
    if ([category isEqualToString:segmentRecentName]) {
        return [self recentEmojis];
    }
    return [self.emojis objectForKey:category];
}

- (NSUInteger)totalNumberOfPages {
    NSUInteger total = 0;
    CGSize frameSize = CGSizeMake(CGRectGetWidth(self.bounds),
                                  CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds)-CGRectGetHeight(self.categoryLabel.bounds));
    
    for (int i = 1; i < self.categoryList.count-1; i++) {
        [self.startingPages setObject:@(total) forKey:[self categoryNameAtIndex:i]];
        total += [self numberOfPagesForCategory:[self categoryNameAtIndex:i] inFrameSize:frameSize];
    }
    
    return total;
}

- (void)setAllPages {
    NSInteger total = 1;
    CGSize frameSize = CGSizeMake(CGRectGetWidth(self.bounds),
                                  CGRectGetHeight(self.bounds) - CGRectGetHeight(self.tabBar.bounds) - CGRectGetHeight(self.categoryLabel.bounds));
    
    for (int i = 2; i < self.categoryList.count; i++) {
        self.category = [self categoryNameAtIndex:i];
        for (int i = 0; i < [self numberOfPagesForCategory:self.category inFrameSize:frameSize]; i++) {
            [self setEmojiPageViewInScrollView:self.emojiPagesScrollView atIndex:i atFrameIndex:total];
            total++;
        }
    }
    
    self.category = [self categoryNameAtIndex:[self defaultSelectedCategory]];
    self.currentPage = 0;
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
    self.currentPage = [self.startingPages[self.category] intValue];
    self.emojiPagesScrollView.contentOffset = CGPointMake(CGRectGetWidth(self.emojiPagesScrollView.bounds) * self.currentPage, 0);
    self.previousCategory = index;
    self.categoryLabel.text = [self.category uppercaseString];
    [self setPage:self.currentPage];
}

@end
