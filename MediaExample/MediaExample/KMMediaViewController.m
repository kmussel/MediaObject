//
//  KMMediaViewController.m
//  MediaExample
//
//  Created by Kevin Musselman on 11/1/12.
//  Copyright (c) 2012 Kevin Musselman. All rights reserved.
//

#import "KMMediaViewController.h"
#import "MediaObject.h"
#import "UIImageView+WebCache.h"

@interface KMMediaViewController ()

@property (nonatomic, strong) MediaObject *media;
@property (nonatomic, strong) UITextView * tview;
@property (nonatomic, strong) UIImageView * preview;
@end

@implementation KMMediaViewController
@synthesize media, tview, preview;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        media = [[MediaObject alloc] initWithDelegate:(id<MediaObjectDelegate>)self];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor grayColor];
    
    CGFloat width =  self.view.frame.size.width;
    UILabel *lb = [[UILabel alloc] initWithFrame:CGRectMake(5, 10, width-10, 18)];
    lb.text = @"Type text here to parse out url";
    lb.font = [UIFont boldSystemFontOfSize:15];
    lb.backgroundColor = [UIColor grayColor];
    [self.view addSubview:lb];
    
    self.tview = [[UITextView alloc] initWithFrame:CGRectMake(0, 40, self.view.frame.size.width, 60)];
    self.tview.delegate = (id<UITextViewDelegate>)self;
    [self.view addSubview:self.tview];
    
    
    self.preview = [[UIImageView alloc] initWithFrame:CGRectMake(0, 110, self.view.frame.size.width, 300)];
    self.preview.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.preview];
	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(BOOL)mediaLink:(NSString *)link
{
    if(link && ![link isEqualToString:@""])
    {
        [self.media setParseUrl:link andRetrieve:YES];
        
        if(self.media.mtype != othermedia)
        {
            [preview setImageWithPath:self.media.photoURL];
            return YES;
        }
    }
    return NO;
}

-(void)parseText
{
    NSArray *comp =  [self.tview.text componentsSeparatedByString:@" "];
    NSRegularExpression *expression = [NSRegularExpression regularExpressionWithPattern:@"(?i)\\b((?:[a-z][\\w-]+:(?:/{1,3}|[a-z0-9%])|www\\d{0,3}[.]|[a-z0-9.\\-]+[.][a-z]{2,4}/)(?:[^\\s()<>]+|\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\))+(?:\\(([^\\s()<>]+|(\\([^\\s()<>]+\\)))*\\)|[^\\s`!()\\[\\]{};:'\".,<>?«»“”‘’]))" options:NSRegularExpressionCaseInsensitive error:NULL];

    BOOL hasMediaLink = NO;
    BOOL currMediaExists = (self.media.mediaURL && ![self.media.mediaURL isEqualToString:@""]);
    if(comp.count)
    {
        for(NSString *txt in comp)
        {
            if(txt.length > 5)
            {
                NSRange rng = [expression rangeOfFirstMatchInString:txt options:NSMatchingCompleted range:NSMakeRange(0, [txt length])];
                if(rng.length>0)
                {
                    NSString *match = [txt substringWithRange:rng];
                    if (!hasMediaLink)
                        hasMediaLink = [self mediaLink:match];
                }
            }
        }
    }

    if (currMediaExists && !hasMediaLink) {
        self.preview.image = nil;
    }
}


#pragma -mark MediaObjectDelegate methods

-(void)didSetPhotoURL
{
    self.preview.image = nil;
    [self.preview  setImageWithPath:self.media.photoURL];
}



#pragma -mark UITextViewDelegate 

- (void)textViewDidChange:(UITextView *)textView
{
    [self parseText];    
}

- (BOOL)textView:(UITextView *)aTextView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)aText
{
    if ([aText isEqualToString:@"\n"])
    {
        [aTextView resignFirstResponder];
        return NO;
    }
    return YES;
}

@end
