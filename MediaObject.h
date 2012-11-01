//
//  MediaObject.h
//  KyckClient
//
//  Created by Kevin Musselman on 10/30/12.
//
//

#import <Foundation/Foundation.h>
#import "NIInMemoryCache.h"

typedef enum
{
    othermedia = 0,
    photo,
    video,
    audio
} MediaType;

typedef enum
{
    othervideo = 0,
    youtube,
    dailymotion
} VideoType;


@protocol MediaObjectDelegate <NSObject>

@optional
-(void)didSetPhotoURL;

@end

@interface MediaObject : NSObject

@property (nonatomic, strong) id<MediaObjectDelegate> delegate;
@property (nonatomic, strong) NSString *originalURL;
@property (nonatomic, strong) NSString *mediaID;
@property (nonatomic, strong) NSString *mediaURL;
@property (nonatomic, strong) NSString *photoURL;
@property (nonatomic, strong) NSNumber *photoRatio;
@property (nonatomic, readwrite) MediaType mtype;
@property (nonatomic, readwrite) VideoType vtype;
@property (nonatomic, readwrite) int numTries;
@property (nonatomic, readwrite) BOOL tryAgain;
@property (nonatomic, strong) NIMemoryCache *memoryCache;

+ (NIMemoryCache *)globalMemoryCache;

-(id)initWithUrl:(NSString *)url;
-(void)parseURL;
-(void)parseURLandRetrieve;
-(void)setParseUrl:(NSString *)url andRetrieve:(BOOL)ret;
-(void)parseURL:(NSString*)url withType:(MediaType)typ;
-(void)storeInMemory;

@end
