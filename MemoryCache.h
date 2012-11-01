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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 * An in-memory cache for storing objects with expiration support.
 *
 * The Nimbus in-memory object cache allows you to store objects in memory with an expiration
 * date attached. Objects with expiration dates drop out of the cache when they have expired.
 */
@interface MemoryCache : NSObject

// Designated initializer.
- (id)initWithCapacity:(NSUInteger)capacity;

- (NSUInteger)count;

- (void)storeObject:(id)object withName:(NSString *)name;
- (void)storeObject:(id)object withName:(NSString *)name expiresAfter:(NSDate *)expirationDate;

- (void)removeObjectWithName:(NSString *)name;
- (void)removeAllObjectsWithPrefix:(NSString *)prefix;
- (void)removeAllObjects;

- (id)objectWithName:(NSString *)name;
- (BOOL)containsObjectWithName:(NSString *)name;


- (void)reduceMemoryUsage;

@end


