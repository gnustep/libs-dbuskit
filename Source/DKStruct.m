/** Categories on NSArray so that it's boxed as D-Bus structures
   Copyright (C) 2014 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2014

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */

#import "DBusKit/DKStruct.h"

@implementation NSArray (DBusKit)
- (BOOL)isDBusStruct
{
  return NO;
}
@end

@implementation DKStructArray
- (BOOL)isDBusStruct
{
  return YES;
}

- (id) initWithObjects: (const id[])objects count: (NSUInteger)count
{
  // Special case, class cluster: No super init
  backingStore = [[NSArray alloc] initWithObjects: objects count: count];
  if (nil == backingStore)
    {
      DESTROY(self);
      return nil;
    }
  return self;
}

- (NSUInteger)count
{
  return [backingStore count];
}

- (id)objectAtIndex: (NSUInteger)index
{
  return [backingStore objectAtIndex: index];
}

- (void)dealloc
{
  DESTROY(backingStore);
  [super dealloc];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state 
                                  objects:(id *)stackbuf 
                                    count:(NSUInteger)len
{
  return [backingStore countByEnumeratingWithState: state
                                           objects: stackbuf
                                             count: len];
}

@end

@implementation DKMutableStructArray
- (BOOL)isDBusStruct
{
  return YES;
}

- (id) initWithCapacity: (NSUInteger)count
{
  // Special case, class cluster: No super init
  backingStore = [[NSMutableArray alloc] initWithCapacity: count];
  if (nil == backingStore)
    {
      DESTROY(self);
      return nil;
    }
  return self;
}

- (NSUInteger)count
{
  return [backingStore count];
}

- (id)objectAtIndex: (NSUInteger)index
{
  return [backingStore objectAtIndex: index];
}

- (void)dealloc
{
  DESTROY(backingStore);
  [super dealloc];
}

- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state 
                                  objects:(id *)stackbuf 
                                    count:(NSUInteger)len
{
  return [backingStore countByEnumeratingWithState: state
                                           objects: stackbuf
                                             count: len];
}

- (void)insertObject: (id)obj atIndex: (NSUInteger)idx
{
  [backingStore insertObject: obj atIndex: idx];
}

- (void)removeObjectAtIndex: (NSUInteger)idx
{
  [backingStore removeObjectAtIndex: idx];
}

- (void)addObject: (id)obj
{
  [backingStore addObject: obj];
}

- (void)removeLastObject
{
  [backingStore removeLastObject];
}


- (void)replaceObjectAtIndex: (NSUInteger)idx withObject: (id)obj
{
  [backingStore replaceObjectAtIndex: idx withObject: obj];
}

@end
