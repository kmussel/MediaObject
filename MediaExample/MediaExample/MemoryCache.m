//
// Copyright 2011 Jeff Verkoeyen
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "MemoryCache.h"


@interface MemoryCache()
// Mapping from a name (usually a URL) to an internal object.
@property (nonatomic, readwrite, retain) NSMutableDictionary* cacheMap;

@end


/**
 * @brief A single cache item's information.
 *
 * Used in expiration calculations and for storing the actual cache object.
 */
@interface MemoryCacheInfo : NSObject

/**
 * @brief The name used to store this object in the cache.
 */
@property (nonatomic, readwrite, copy) NSString* name;

/**
 * @brief The object stored in the cache.
 */
@property (nonatomic, readwrite, retain) id object;

/**
 * @brief The date after which the image is no longer valid and should be removed from the cache.
 */
@property (nonatomic, readwrite, retain) NSDate* expirationDate;

/**
 * @brief The last time this image was accessed.
 *
 * This property is updated every time the image is fetched from or stored into the cache. It
 * is used when the memory peak has been reached as a fast means of removing least-recently-used
 * images. When the memory limit is reached, we sort the cache based on the last access times and
 * then prune images until we're under the memory limit again.
 */
@property (nonatomic, readwrite, retain) NSDate* lastAccessTime;


/**
 * @brief Determine whether this cache entry has past its expiration date.
 *
 * @returns YES if an expiration date has been specified and the expiration date has been passed.
 *          NO in all other cases. Notably if there is no expiration date then this object will
 *          never expire.
 */
- (BOOL)hasExpired;

@end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MemoryCache

@synthesize cacheMap        = _cacheMap;


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)init {
  return [self initWithCapacity:0];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)initWithCapacity:(NSUInteger)capacity {
  if ((self = [super init])) {
    _cacheMap = [[NSMutableDictionary alloc] initWithCapacity:capacity];

    // Automatically reduce memory usage when we get a memory warning.
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(reduceMemoryUsage)
                                                 name: UIApplicationDidReceiveMemoryWarningNotification
                                               object: nil];
  }
  return self;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)description {
  return [NSString stringWithFormat:
          @"<%@"
          @" cache map: %@"
          @">",
          [super description],
          self.cacheMap];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Internal Methods


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)updateAccessTimeForInfo:(MemoryCacheInfo *)info {
  assert(nil != info);
  if (nil == info) {
    return; // COV_NF_LINE
  }
  info.lastAccessTime = [NSDate date];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (MemoryCacheInfo *)cacheInfoForName:(NSString *)name {
  return [self.cacheMap objectForKey:name];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)setCacheInfo:(MemoryCacheInfo *)info forName:(NSString *)name {
  assert(nil != name);
  if (nil == name) {
    return;
  }

  // Storing in the cache counts as an access of the object, so we update the access time.
  [self updateAccessTimeForInfo:info];

  [self.cacheMap setObject:info forKey:name];

}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)removeCacheInfoForName:(NSString *)name {
  assert(nil != name);
  if (nil == name) {
    return;
  }

  [self.cacheMap removeObjectForKey:name];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
#pragma mark Public Methods


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)storeObject:(id)object withName:(NSString *)name {
  [self storeObject:object withName:name expiresAfter:nil];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)storeObject:(id)object withName:(NSString *)name expiresAfter:(NSDate *)expirationDate {
  // Don't store nil objects in the cache.
  if (nil == object) {
    return;
  }

  if (nil != expirationDate && [[NSDate date] timeIntervalSinceDate:expirationDate] >= 0) {
    // The object being stored is already expired so remove the object from the cache altogether.
    [self removeObjectWithName:name];

    // We're done here.
    return;
  }
  MemoryCacheInfo* info = [self cacheInfoForName:name];

  // Create a new cache entry.
  if (nil == info) {
    info = [[MemoryCacheInfo alloc] init];
    info.name = name;
  }

  // Store the object in the cache item.
  info.object = object;

  // Override any existing expiration date.
  info.expirationDate = expirationDate;

  // Commit the changes to the cache.
  [self setCacheInfo:info forName:name];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (id)objectWithName:(NSString *)name {
  MemoryCacheInfo* info = [self cacheInfoForName:name];

  id object = nil;

  if (nil != info) {
    if ([info hasExpired]) {
      [self removeObjectWithName:name];

    } else {
      // Update the access time whenever we fetch an object from the cache.
      [self updateAccessTimeForInfo:info];

      object = info.object;
    }
  }

  return object;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)containsObjectWithName:(NSString *)name {
  MemoryCacheInfo* info = [self cacheInfoForName:name];

  if ([info hasExpired]) {
    [self removeObjectWithName:name];
    return NO;
  }

  return (nil != info);
}



///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)removeObjectWithName:(NSString *)name {
  [self removeCacheInfoForName:name];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)removeAllObjectsWithPrefix:(NSString *)prefix {
  for (NSString* key in [self.cacheMap copy]) {
    if ([key hasPrefix:prefix]) {
      [self removeObjectWithName:key];
    }
  }
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)removeAllObjects {
  self.cacheMap = [[NSMutableDictionary alloc] init];
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (void)reduceMemoryUsage {
  // Copy the cache map because it's likely that we're going to modify it.
  NSDictionary* cacheMap = [self.cacheMap copy];

  // Iterate over the copied cache map (which will not be modified).
  for (id name in cacheMap) {
    MemoryCacheInfo* info = [self cacheInfoForName:name];

    if ([info hasExpired]) {
      [self removeCacheInfoForName:name];
    }
  }
  cacheMap = nil;
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSUInteger)count {
  return [self.cacheMap count];
}


@end


///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////
@implementation MemoryCacheInfo

@synthesize name            = _name;
@synthesize object          = _object;
@synthesize expirationDate  = _expirationDate;
@synthesize lastAccessTime  = _lastAccessTime;


///////////////////////////////////////////////////////////////////////////////////////////////////
- (BOOL)hasExpired {
  return (nil != _expirationDate
          && [[NSDate date] timeIntervalSinceDate:_expirationDate] >= 0);
}


///////////////////////////////////////////////////////////////////////////////////////////////////
- (NSString *)description {
  return [NSString stringWithFormat:
          @"<%@"
          @" name: %@"
          @" object: %@"
          @" expiration date: %@"
          @" last access time: %@"
          @">",
          [super description],
          self.name,
          self.object,
          self.expirationDate,
          self.lastAccessTime];
}


@end


