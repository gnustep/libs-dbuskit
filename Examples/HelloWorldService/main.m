/* main.m for D-Bus service example
 *
 * Copyright (C) 2012 Free Software Foundation, Inc.
 *
 * Written by:  Niels Grewe
 * Created:  May 2012
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111
 * USA.
 */


#import <DBusKit/DBusKit.h>
#import <Foundation/Foundation.h>

@interface NSObject (PrivateStuffDoNotUse)
- (BOOL)_loadIntrospectionFromFile: (NSString*)path;
- (id) _objectPathNodeAtPath: (NSString*)string;
@end

@interface Poster : NSObject
{
  id obj;
  DKNotificationCenter *center;
}
@end

@implementation Poster
- (id)initWithProxiedObject: (id)anObject
{
  if (nil == (self = [super init]))
    {
      return nil;
    }
  ASSIGN(obj, anObject);
  center = [[DKNotificationCenter sessionBusCenter] retain];
  return self;
}

- (void)post: (NSTimer*)timer
{
  [center postSignalName: @"notification"
               interface: @"org.gnustep.test"
                  object: obj];
}

- (void)dealloc
{
  DESTROY(obj);
  DESTROY(center);
}
@end


int main()
{
  DKPort *p = (DKPort*)[DKPort port];
  id obj = @"p";
  // WARNING: This is not a public API. Don't use it.
  [p _setObject: obj atPath: @"/org/gnustep/test/p"];
  id pProxy = [p _objectPathNodeAtPath: @"/org/gnustep/test/p"];
  [pProxy _loadIntrospectionFromFile: @"test.xml"];
  Poster *poster = [[Poster alloc] initWithProxiedObject: obj];
  NSTimer *t = [NSTimer scheduledTimerWithTimeInterval: 5.0
                                                target: poster
                                              selector: @selector(post:)
                                              userInfo: nil
                                               repeats: YES];
  while (1)
  {
    [[NSRunLoop currentRunLoop] run];
  }
  [t invalidate];
  [poster release];
  return 0;
}


