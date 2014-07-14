//
//  MDViewController.m
//  MJAutoCompleteDemo
//
//  Created by Mazyad Alabduljaleel on 2/18/14.
//  Copyright (c) 2014 ArabianDevs. All rights reserved.
//

#import "MDViewController.h"
#import "MDCustomAutoCompleteCell.h"
#import "UIImageView+WebCache.h"

@interface MDViewController ()

@property (nonatomic) BOOL didStartDownload;

@property (strong, nonatomic) MJAutoCompleteManager *autoCompleteMgr;

@property (weak, nonatomic) IBOutlet UIView *autoCompleteContainer;
@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation MDViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        self.autoCompleteMgr = [[MJAutoCompleteManager alloc] init];
        self.autoCompleteMgr.dataSource = self;
        self.autoCompleteMgr.delegate = self;
        /* Add some autoComplete triggers */
        // let's get the names of the countries
        NSString *path = [[NSBundle mainBundle] pathForResource:@"Countries" ofType:@"plist"];
        NSArray *names = [[NSArray arrayWithContentsOfFile:path] valueForKey:@"name"];
        NSArray *items = [MJAutoCompleteItem autoCompleteCellModelFromObjects:names];

        // then assign them to the trigger
        /* For the # trigger, we demonstrate the absolute easiest way to get started */
        MJAutoCompleteTrigger *hashTrigger = [[MJAutoCompleteTrigger alloc] initWithDelimiter:@"#"
                                                                            autoCompleteItems:items];
        /* For the @ trigger, it is much more complex, with lots of async thingies */
        MJAutoCompleteTrigger *atTrigger = [[MJAutoCompleteTrigger alloc] initWithDelimiter:@"@"];
        atTrigger.cell = @"MDCustomAutoCompleteCell";
        // assign them triggers to autoCompleteMgr
        [self.autoCompleteMgr addAutoCompleteTrigger:hashTrigger];
        [self.autoCompleteMgr addAutoCompleteTrigger:atTrigger];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // hook up the container with the manager
    self.autoCompleteMgr.container = self.autoCompleteContainer;
    // and hook up the textView delegate
    self.textView.delegate = self;
}

#pragma mark - UITextView Delegate methods

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
 
    
    //[self.autoCompleteMgr updateTextView:textView changeTextInRange:range replacementText:text];
    
    NSLog(@"textView.text:%@ \n range:%@, \n text:%@ ",textView.text, NSStringFromRange(range), text);
    
   NSRange hotWordRange;
    NSDictionary *dict;
    for (dict in self.autoCompleteMgr.rangesOfSelectedHotWords) {
        hotWordRange = [[dict objectForKey:@"range"] rangeValue];
        
        NSRange intersection = NSIntersectionRange(hotWordRange, range);
        
        NSLog(@"hotWordRange :%@ \n intersection:%@",NSStringFromRange(hotWordRange),NSStringFromRange(intersection));
        
        if (NSIntersectionRange(hotWordRange, range).length <= 0)
        {
            NSLog(@"Ranges do not intersect");
            
        } else {
            NSLog(@"Intersection = %@", NSStringFromRange(intersection));
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithString:textView.text];
            
            [attributedString removeAttribute:NSBackgroundColorAttributeName range:hotWordRange];
            [attributedString removeAttribute:NSForegroundColorAttributeName range:hotWordRange];
            NSString *result =  [textView.text stringByReplacingCharactersInRange:hotWordRange withString:@""];
            textView.attributedText = attributedString;

            textView.text = result;
            NSLog(@"----textView.text:%@ , \n result:%@",textView.text, result);
            
            NSLog(@"rangesOfSelectedHotWords:%d",self.autoCompleteMgr.rangesOfSelectedHotWords.count);
            [self.autoCompleteMgr.rangesOfSelectedHotWords removeObject:dict];
            
            NSLog(@"rangesOfSelectedHotWords:%d",self.autoCompleteMgr.rangesOfSelectedHotWords.count);
            [self highlightHotWordsInTextView:textView];
            }

        //[self highlightHotWordsInTextView:textView];
        NSRange myRange = range;
        NSLog(@"----- range:%@, \n hotWordRange:%@ ", NSStringFromRange(myRange), NSStringFromRange(hotWordRange));

        myRange.location -=2;
        NSLog(@"------- range:%@, \n hotWordRange:%@ ", NSStringFromRange(myRange), NSStringFromRange(hotWordRange));

        if (NSIntersectionRange(hotWordRange, myRange).length <= 0)
        {
        } else{
            NSLog(@"M right range:%@ ", NSStringFromRange(myRange));
            [self highlightHotWordsInTextView:textView];
        }
    }
     return YES;
}

- (void)highlightHotWordsInTextView:(UITextView *)textView
{
    NSRange range;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithString:textView.text];
    for (NSDictionary *dict in self.autoCompleteMgr.rangesOfSelectedHotWords) {
        range = [[dict objectForKey:@"range"] rangeValue];
        [attributedString addAttribute:NSBackgroundColorAttributeName
                                     value:[UIColor redColor]
                                     range:range];
        [attributedString addAttribute:NSForegroundColorAttributeName
                                     value:[UIColor whiteColor]
                                     range:range];
    }
    textView.attributedText = attributedString;
}

- (void)textViewDidChange:(UITextView *)textView
{
    [self.autoCompleteMgr processString:textView.text];
}

#pragma mark - MJAutoCompleteMgr DataSource Methods

- (void)autoCompleteManager:(MJAutoCompleteManager *)acManager
         itemListForTrigger:(MJAutoCompleteTrigger *)trigger
                 withString:(NSString *)string
                   callback:(MJAutoCompleteListCallback)callback
{
    /* Since we implemented this method, we are stuck and must handle ALL triggers */
    // the # trigger is trivial:
    if ([trigger.delimiter isEqual:@"#"])
    {
        // we already provided the list
        callback(trigger.autoCompleteItemList);
    }
    else if ([trigger.delimiter isEqual:@"@"])
    {
        if (!self.didStartDownload)
        {
            self.didStartDownload = YES;
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^
            {
                NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:@"http://alltheragefaces.com/api/all/faces"]];
                NSArray *jsonData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                
                NSMutableArray *itemList = [NSMutableArray array];
                for (NSDictionary *dict in jsonData)
                {
                    // Use DICT_GET to handle NSNull cases
                    NSString * acString = DICT_GET(dict, @"title");
                    acString = [acString stringByReplacingOccurrencesOfString:@" " withString:@""];
                    
                    MJAutoCompleteItem *item = [[MJAutoCompleteItem alloc] init];
                    item.autoCompleteString = acString;
                    item.context = dict;
                    
                    [itemList addObject:item];
                }
                
                dispatch_async(dispatch_get_main_queue(), ^
                {
                    trigger.autoCompleteItemList = itemList;
                    callback(itemList);
                });
            });
        }
        else
        {
            callback(trigger.autoCompleteItemList);
        }
    }
}

#pragma mark - MJAutoCompleteMgr Delegate methods

- (void)autoCompleteManager:(MJAutoCompleteManager *)acManager
            willPresentCell:(id)autoCompleteCell
                 forTrigger:(MJAutoCompleteTrigger *)trigger
{
    if ([trigger.delimiter isEqual:@"@"])
    {
        MDCustomAutoCompleteCell *cell = autoCompleteCell;
        NSDictionary *context = cell.autoCompleteItem.context;
        
        [cell.avatarImageView setImageWithURL:[NSURL URLWithString:DICT_GET(context, @"jpg")]
                             placeholderImage:[UIImage imageNamed:@"placeholder"]];
    }
}

- (void)autoCompleteManager:(MJAutoCompleteManager *)acManager shouldUpdateToText:(NSString *)newText
{
    
    self.textView.text = newText;
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithString:self.textView.text];
    NSRange range;
    for (NSDictionary *dict in acManager.rangesOfSelectedHotWords) {
        range = [[dict objectForKey:@"range"] rangeValue];
        [attributedString addAttribute:NSBackgroundColorAttributeName
                       value:[UIColor redColor]
                       range:range];
        [attributedString addAttribute:NSForegroundColorAttributeName
                                 value:[UIColor whiteColor]
                                 range:range];
    }
    self.textView.attributedText = attributedString;
}

#pragma mark -

@end
