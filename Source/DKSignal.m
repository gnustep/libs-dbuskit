/** Implementation of DKSignal (encapsulation of D-Bus signal information).
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: July 2010

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

#import "DKSignal.h"

#import "DKArgument.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSString.h>

#import "DBusKit/DKNotificationCenter.h"
#import "DKProxy+Private.h"
#import "DKEndpoint.h"

@interface DKNotificationCenter (Private)
- (void)_registerSignal: (DKSignal*)signal;
@end

@implementation DKSignal

- (id) initWithName: (NSString*)aName
             parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }
  if (0 == [name length])
  {
    [self release];
    return nil;
  }
  args = [NSMutableArray new];
  return self;
}

- (void)addArgument: (DKArgument*)argument
          direction: (NSString*)direction
{
  if (nil == argument)
  {
    NSDebugMLog(@"Ignoring nil argument");
    return;
  }

  if ((direction == nil) || [direction isEqualToString: DKArgumentDirectionOut])
  {
    [args addObject: argument];
  }
  else
  {
    NSDebugMLog(@"Ignoring argument with invalid direction '%@'.", direction);
  }
}

- (void)setArguments: (NSMutableArray*)newArgs
{
  ASSIGN(args,newArgs);
  [args makeObjectsPerformSelector: @selector(setParent:) withObject: self];
}

- (id)copyWithZone: (NSZone*)zone
{
  DKSignal *newNode = [super copyWithZone: zone];
  NSMutableArray *newArgs = nil;
  newArgs = [[NSMutableArray allocWithZone: zone] initWithArray: args
                                                      copyItems: YES];
  [newNode setArguments: newArgs];
  [newArgs release];
  return newNode;
}

- (NSString*)notificationName
{
  return [annotations objectForKey: @"org.gnustep.openstep.notification"];
}

- (void)registerWithNotificationCenter: (DKNotificationCenter*)center
{
  [center _registerSignal: self];
}

- (void)registerWithNotificationCenter
{
  DKProxy *theProxy = [self proxyParent];
  DKNotificationCenter *theCenter = nil;
  if (nil == theProxy)
  {
    return;
  }
  theCenter = [DKNotificationCenter centerForBusType: [[theProxy _endpoint] DBusBusType]];
  [self registerWithNotificationCenter: theCenter];
}

- (void)dealloc
{
  [args release];
  [super dealloc];
}
@end
