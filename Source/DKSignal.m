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
#import <Foundation/NSException.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLNode.h>

#import "DBusKit/DKNotificationCenter.h"
#import "DKProxy+Private.h"
#import "DKEndpoint.h"

#include <dbus/dbus.h>

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

  if ((direction == nil) || [direction isEqualToString: kDKArgumentDirectionOut])
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

- (BOOL)isStub
{
  return [[annotations objectForKey: @"org.gnustep.dbuskit.signal.stub"] boolValue];
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

- (NSDictionary*)userInfoFromIterator: (DBusMessageIter*)iter
{
  NSUInteger numArgs = [args count];
  NSMutableDictionary *userInfo = [[NSMutableDictionary new] autorelease];
  NSUInteger index = 0;
  while (index < (numArgs))
  {
    NSString *key = [NSString stringWithFormat: @"arg%lu", index];
    DKArgument *arg = (DKArgument*)[args objectAtIndex: index];
    NSString *annotatedKey = [arg annotationValueForKey: @"org.gnustep.openstep.notification.key"];

    id value = nil;
    if (DBUS_TYPE_OBJECT_PATH == [arg DBusType])
    {
      value = [arg unmarshalledProxyStandinFromIterator: iter];
    }
    else
    {
      value = [arg unmarshalledObjectFromIterator: iter];
    }
    if (nil == value)
    {
      value = [NSNull null];
    }
    [userInfo setObject: value
                 forKey: key];

    if (nil != annotatedKey)
    {
      [userInfo setObject: value
                   forKey: annotatedKey];
    }
    index++;
    if ((NO == (BOOL)dbus_message_iter_next(iter)) && (index < numArgs))
    {
      [NSException raise: @"DKSignalUnmarshallingException"
                  format: @"D-Bus message too short when unmarshalling arguments for signal '%@'.",
        name];
    }
  }
  return userInfo;
}

- (void)marshallUserInfo: (NSDictionary*)userInfo
            intoIterator: (DBusMessageIter*)iter
{
  NSUInteger numArgs = [args count];
  NSUInteger index = 0;
  for (index = 0; index < numArgs; index++)
  {
    NSString *key = [NSString stringWithFormat: @"arg%lu", index];
    DKArgument *arg = (DKArgument*)[args objectAtIndex: index];
    NSString *annotatedKey = [arg annotationValueForKey: @"org.gnustep.openstep.notification.key"];

    id value = nil;
    if (nil != annotatedKey)
      {
        value = [userInfo objectForKey: annotatedKey];
      }
  
    if (nil == value)
     {
       // second try, with the argN key
       value = [userInfo objectForKey: key];
     }
    [arg marshallObject: value
           intoIterator: iter];
  }
}

- (NSInteger)argumentIndexForAnnotatedKey: (NSString*)key
{
 
  NSEnumerator *argEnum = [args objectEnumerator];
  DKArgument *arg = nil;
  NSInteger index = 0;
  while (nil != (arg = [argEnum nextObject]))
  {
    NSString *annotatedKey = [arg annotationValueForKey: @"org.gnustep.openstep.notification.key"];
    if ([annotatedKey isEqualToString: key])
      {
        return index;
      } 
    index++;
  }
  return NSNotFound;
}

- (NSXMLNode*)XMLNode
{
  NSXMLNode *nameAttribute = [NSXMLNode attributeWithName: @"name"
                                              stringValue: name];
  NSMutableArray *childNodes = [NSMutableArray array];
  NSEnumerator *argEnum = [args objectEnumerator];
  DKArgument *arg = nil;
  while (nil != (arg = [argEnum nextObject]))
  {
    // Signal arguments should not carry a "direction" attribute
    NSXMLNode *n = [arg XMLNode];
    if (nil != n)
    {
      [childNodes addObject: n];
    }
  }

  [childNodes addObjectsFromArray: [self annotationXMLNodes]];

  return [NSXMLNode elementWithName: @"signal"
                           children: childNodes
                         attributes: [NSArray arrayWithObject: nameAttribute]];
}


- (void)dealloc
{
  [args release];
  [super dealloc];
}
@end
