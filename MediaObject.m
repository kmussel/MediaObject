//
//  MediaObject.m
//  KyckClient
//
//  Created by Kevin Musselman on 10/30/12.
//
//

#import "MediaObject.h"

typedef void(^OemebdCB)(NSDictionary*);

@interface MediaObject()
@property (nonatomic, readwrite) BOOL isRetrieving;
@end

@implementation MediaObject
@synthesize isRetrieving;
@synthesize delegate, originalURL, mediaID, mediaURL, photoRatio, photoURL, mtype, vtype, memoryCache, numTries, tryAgain;

+ (MemoryCache *)globalMemoryCache
{
    static MemoryCache *sharedCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCache = [[MemoryCache alloc] init];
    });
    
    return sharedCache;
}

-(id)initWithDelegate:(id<MediaObjectDelegate>)del
{
    if((self=[self init]))
    {
        self.delegate = del;
    }
    return self;
}

-(id)init
{
    if((self=[super init]))
    {
        self.memoryCache = [MediaObject globalMemoryCache];
        originalURL = @"";
        photoRatio = [NSNumber numberWithInt:1];
        mediaURL = @"";
        mediaID = @"";
        numTries = 0;
        tryAgain = YES;
        isRetrieving = NO;
        
    }
    return self;
}


-(BOOL)parseYoutube
{
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:youtube\\.com\\/(?:[^\\/]+\\/.+\\/|(?:v|e(?:mbed)?)\\/|.*[?&]v=)|youtu\\.be\\/)([^\"&?\\/ \"]{11})" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *matches = [regex matchesInString:originalURL options:0 range:NSMakeRange(0, [originalURL length])];
    
    NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
    if (match && match.numberOfRanges>1)
    {
        mediaID  = [originalURL substringWithRange:[match rangeAtIndex:1]];
        mediaURL = [NSString stringWithFormat:@"http://www.youtube.com/embed/%@", mediaID];
        photoURL = [NSString stringWithFormat:@"http://img.youtube.com/vi/%@/0.jpg", mediaID];
        photoRatio = [NSNumber numberWithFloat:1.3333];
        mtype = video;
        vtype = youtube;
        
        [self storeInMemory];
        return YES;
    }
    
    return NO;
}

-(BOOL)parseDailyMotion
{
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:dailymotion\\.com\\/(?:embed\\/)?video\\/(?:([^_]+).*))|(?:dai\\.ly\\/(.*))" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *matches = [regex matchesInString:originalURL options:0 range:NSMakeRange(0, [originalURL length])];
    NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
    
    if (match && match.numberOfRanges>1)
    {
        mtype = video;
        vtype = dailymotion;

        if ([match rangeAtIndex:1].location != NSNotFound)
        {
            mediaID  = [originalURL substringWithRange:[match rangeAtIndex:1]];
            mediaURL = [NSString stringWithFormat:@"http://www.dailymotion.com/embed/video/%@", mediaID];
            photoURL = [NSString stringWithFormat:@"http://www.dailymotion.com/thumbnail/video/%@", mediaID];
            photoRatio = [NSNumber numberWithFloat:1.3333];
        }
        [self storeInMemory];
        
        return YES;
    }
    return NO;
}

-(BOOL)parseFlicker
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:flickr\\.com\\/|flic\\.kr\\/)" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *matches = [regex matchesInString:originalURL options:0 range:NSMakeRange(0, [originalURL length])];
    NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
    if (match && match.numberOfRanges>0)
    {
        mediaURL = originalURL;
        mtype = photo;
        vtype = othervideo;
        [self storeInMemory];
        
        return YES;
    }
    return NO;
}

-(BOOL)parseInstagram
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:instagram\\.com\\/|instagr\\.am\\/)" options:NSRegularExpressionCaseInsensitive error:NULL];
    NSArray *matches = [regex matchesInString:originalURL options:0 range:NSMakeRange(0, [originalURL length])];
    NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
    if (match && match.numberOfRanges>0)
    {
        mediaURL = originalURL;
        mtype = photo;
        vtype = othervideo;
        
        [self storeInMemory];
        return YES;
    }
    
    return NO;
}


-(void)makeOembedCall:(NSString *)baseURL withCallback:(OemebdCB)cb
{
    isRetrieving = YES;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{

        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/services/oembed?format=json&url=%@", baseURL, self.originalURL]]];
        NSError* networkError = nil;
        NSURLResponse* response = nil;
        NSData* data  = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&networkError];
        
        // If we get a 404 error then the request will not fail with an error, so only let successful
        // responses pass.
        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
                networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            isRetrieving = NO;
            if (nil != networkError) {
                tryAgain = NO;
                [self storeInMemory];
                return;
            }
            else
            {
                NSError *error = nil;
                id obj =  [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if ([obj isKindOfClass:[NSDictionary class]]) {
                    cb(obj);
                }
            }
        });
    });
    
}

-(void)setParseUrl:(NSString *)url andRetrieve:(BOOL)ret
{
    
    originalURL = url;

    NSDictionary *obj = [self.memoryCache objectWithName:originalURL];
    if(obj)
    {
        if(obj[@"mediaURL"]) mediaURL = obj[@"mediaURL"];
        if(obj[@"mediaID"]) mediaID = obj[@"mediaID"];
        if(obj[@"photoURL"] && ![obj[@"photoURL"] isEqualToString:@""]) photoURL = obj[@"photoURL"];
        if(obj[@"photoRatio"]) photoRatio = obj[@"photoRatio"];
        if(obj[@"mtype"]) mtype = [obj[@"mtype"] intValue];
        if(obj[@"vtype"]) vtype = [obj[@"vtype"] intValue];
        if (obj[@"numTries"]) numTries = [obj[@"numTries"] intValue];
        if (obj[@"tryAgain"]) tryAgain = [obj[@"tryAgain"] boolValue];
        
        
        if (ret)
        {
            if (!(!photoURL || [photoURL isEqualToString:@""]) || !tryAgain || numTries>3 || isRetrieving)
            {
                return;
            }
        }
        else
        {
            return;
        }
    }
    numTries = 0;
    tryAgain = YES;
    mtype = othermedia;
    vtype = othervideo;
    if (ret) {
        photoRatio = [NSNumber numberWithInt:1];
        photoURL = nil;
        photoRatio = nil;
        [self parseURLandRetrieve];
    }
    else
    {
        [self parseURL];
    }
}

-(void)parseURL
{
    
    if ([self parseYoutube]) {
        
    }
    else if([self parseDailyMotion])
    {
        
    }
    else if([self parseFlicker])
    {
        
    }
    else if([self parseInstagram])
    {
        
    }
}

-(void)parseURLandRetrieve
{
    if ([self parseYoutube]) {
        
    }
    else if([self parseDailyMotion])
    {

        if (!self.mediaURL || [self.mediaURL isEqualToString:@""])
        {

            [self makeOembedCall:@"http://www.dailymotion.com" withCallback:^(NSDictionary *obj) {
                
                
                NSString *html = [obj objectForKey:@"html"];
                if(html)
                {
                    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"(?:src=(?:\"|\')([^\"\']+))" options:NSRegularExpressionCaseInsensitive error:NULL];
                    NSArray *matches = [regex matchesInString:html options:0 range:NSMakeRange(0, [html length])];
                    NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
                    if (match && match.numberOfRanges>1)
                    {
                        self.mediaURL = [html substringWithRange:[match rangeAtIndex:1]];
                    }
                }
                
                NSString *thumb = [obj objectForKey:@"thumbnail_url"];
                if(thumb)
                {
                    self.photoURL = thumb;
                    
                    CGFloat width = [[obj objectForKey:@"thumbnail_width"] floatValue];
                    CGFloat height = [[obj objectForKey:@"thumbnail_height"] floatValue];
                    if (height>0) {
                        CGFloat ratio = width/height;
                        self.photoRatio = [NSNumber numberWithFloat:ratio];
                        if ([self.delegate respondsToSelector:@selector(didSetPhotoURL)]) {
                            [self.delegate didSetPhotoURL];
                        }
                    }
                }
                [self storeInMemory];
                
            }];
        }
    }
    else if([self parseFlicker])
    {

        self.numTries++;
        [self storeInMemory];
        
        [self makeOembedCall:@"http://www.flickr.com" withCallback:^(NSDictionary *obj) {
            NSString *thumb = [obj objectForKey:@"thumbnail_url"];
            if(thumb)
            {
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"([^_]+_?[A-Z0-9]+)(_.)?(\\..*)" options:NSRegularExpressionCaseInsensitive error:NULL];
                NSArray *matches = [regex matchesInString:thumb options:0 range:NSMakeRange(0, [thumb length])];
                NSTextCheckingResult *match = (matches.count>0 ? [matches objectAtIndex:0] : nil);
                if (match && match.numberOfRanges>2)
                {
                    
                    NSString * p1 = [thumb substringWithRange:[match rangeAtIndex:1]];
                    NSString * p2 = [thumb substringWithRange:[match rangeAtIndex:3]];
                    if(![match rangeAtIndex:1].location == NSNotFound)
                    {
                        
                    }
                    NSString *final = [NSString stringWithFormat:@"%@%@", p1, p2];
                    
                    self.photoURL = final;
                    
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                        
                        NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:self.photoURL]];
                        NSError* networkError = nil;
                        NSURLResponse* response = nil;
                        NSData* data  = [NSURLConnection sendSynchronousRequest:req returningResponse:&response error:&networkError];
                        
                        // If we get a 404 error then the request will not fail with an error, so only let successful
                        // responses pass.
                        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                            NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse *)response;
                            if (httpResponse.statusCode < 200 || httpResponse.statusCode >= 300) {
                                networkError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorResourceUnavailable userInfo:nil];
                            }
                        }
                        if (nil != networkError) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                tryAgain = NO;
                                [self storeInMemory];
                                return;
                            });
                        }
                        
                        UIImage *img = [[UIImage alloc] initWithData:data];
                        CGFloat ratio = (img ? img.size.width/img.size.height : 0);
                        dispatch_async(dispatch_get_main_queue(), ^{
                            self.photoRatio = [NSNumber numberWithFloat:ratio];
                            if ([self.delegate respondsToSelector:@selector(didSetPhotoURL)]) {
                                [self.delegate didSetPhotoURL];
                            }
                            [self storeInMemory];
                        });
                        
                    });
                }
            }
            else
            {
                [self storeInMemory];
            }
        }];
        
    }
    else if([self parseInstagram])
    {
        self.numTries++;
        [self storeInMemory];
        
        [self makeOembedCall:@"http://api.instagram.com" withCallback:^(NSDictionary *obj) {
            
            NSString *thumb = [obj objectForKey:@"url"];
            if(thumb)
            {
                self.photoURL = thumb;
                
                CGFloat width = [[obj objectForKey:@"width"] floatValue];
                CGFloat height = [[obj objectForKey:@"height"] floatValue];
                if (height>0) {
                    CGFloat ratio = width/height;
                    self.photoRatio = [NSNumber numberWithFloat:ratio];
                    if ([self.delegate respondsToSelector:@selector(didSetPhotoURL)]) {
                        [self.delegate didSetPhotoURL];
                    }
                }
            }
            [self storeInMemory];
        }];
    }
}


-(void)storeInMemory
{
    
    NSDictionary *dict = @{@"mediaURL":mediaURL, @"mediaID": (mediaID ? mediaID : @""), @"photoURL": (photoURL ? photoURL : @""), @"photoRatio": (photoRatio ? photoRatio : @""), @"mtype":[NSNumber numberWithInt:mtype], @"vtype":[NSNumber numberWithInt:vtype], @"numTries":[NSNumber numberWithInt:numTries], @"tryAgain":[NSNumber numberWithBool:tryAgain]};
    NSDate *dt = [NSDate dateWithTimeIntervalSinceNow:600];
    [self.memoryCache storeObject:dict withName:originalURL expiresAfter:dt];
}


@end
