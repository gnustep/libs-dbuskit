/** Implementation of the DKInterface class encapsulating D-Bus interface information.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: June 2010

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

#import <Foundation/NSDictionary.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLParser.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#import "DKMethod.h"
#import "DKInterface.h"


@implementation DKInterface
- (id) initWithName: (NSString*)aName
             parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }

  if (0 == [aName length])
  {
    [self release];
    return nil;
  }
  ASSIGNCOPY(name,aName);
  parent = aParent;

  methods = [NSMutableDictionary new];

  selectorToMethodMap = NSCreateMapTable(NSIntMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    10);
  return self;
}

- (NSArray*)methods
{
  return [methods allValues];
}

/**
 * Adds a method to the interface.
 */
- (void) addMethod: (DKMethod*)method
{
  NSString *methodName = [method name];
  if (0 != [methodName length])
  {
    if (nil != [methods objectForKey: name])
    {
      NSWarnMLog(@"Not adding duplicate method '%@' to interface '%@'.",
        methodName, name);
      return;
    }
    [methods setObject: method
                forKey: methodName];
  }
}

- (void) installMethod: (DKMethod*)method
           forSelector: (SEL)selector
{
  if ((method == nil) || (0 == selector))
  {
    return;
  }

  if (nil == [methods objectForKey: [method name]])
  {
    [self addMethod: method];
  }
  if (NULL != NSMapInsertIfAbsent(selectorToMethodMap, selector, method))
  {
    NSWarnMLog(@"Overloading selector '%@' for method '%@' in interface '%@' not supported",
      NSStringFromSelector(selector),
      [method name],
      name);
  }
}

- (DKMethod*) methodForSelector: (SEL)selector
{
  return NSMapGet(selectorToMethodMap, selector);
}

- (NSString*)mangledName
{
  return [name stringByReplacingOccurrencesOfString: @"." withString: @"_"];
}

- (NSString*)protocolDeclaration
{
  NSMutableString *declaration = [NSMutableString stringWithFormat: @"@protocol %@\n\n", [self mangledName]];
  NSEnumerator *methodEnum = [methods objectEnumerator];
  DKMethod *method = nil;

  while (nil != (method = [methodEnum nextObject]))
  {
    [declaration appendFormat: @"%@\n\n", [method methodDeclaration]];
  }

  [declaration appendFormat: @"@end"];
  return declaration;
}

- (Protocol*)protocol
{
  // TODO: Look aside if another protocol was named to correspond to this
  // interface.
  return NSProtocolFromString([self mangledName]);
}

- (void)dealloc
{
  [methods release];
  NSFreeMapTable(selectorToMethodMap);
  [super dealloc];
}
@end
