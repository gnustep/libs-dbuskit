/* Unit tests for DKInterface
   Copyright (C) 2012 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: January 2012

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
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <UnitKit/UnitKit.h>

#import "../Source/DKInterface.h"
#import "../Source/DKProxy+Private.h"

#include <string.h>
@interface TestDKInterface: NSObject <UKTest>
@end

@implementation TestDKInterface
+ (void)initialize
{
  if ([TestDKInterface class] == self)
  {
    // Do this to initialize the global introspection method:
    [DKProxy class];
  }
}

- (void)testBuiltInIntrospectableInterface
{
  UKNotNil(_DKInterfaceIntrospectable);
  UKObjectsEqual(@"org.freedesktop.DBus.Introspectable", [_DKInterfaceIntrospectable name]);
  UKNotNil([_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)]);
}
- (void)testXMLNode
{
  //We use our builtin introspection method for this.
  NSXMLNode *n = [_DKInterfaceIntrospectable XMLNode];
  UKNotNil(n);
  UKObjectsEqual(@"<interface name=\"org.freedesktop.DBus.Introspectable\">\n\
    <method name=\"Introspect\">\n\
      <arg name=\"data\" type=\"s\" direction=\"in\"/>\n\
    </method>\n\
  </interface>", [n XMLString]);
}
@end
