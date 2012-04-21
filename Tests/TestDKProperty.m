/* Unit tests for DKProperty
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

#import <Foundation/NSXMLNode.h>

#import <UnitKit/UnitKit.h>

#import "../Source/DKProperty.h"

@interface TestDKProperty: NSObject <UKTest>
@end

@implementation TestDKProperty

- (void)testXMLNode
{
  //We use our builtin introspection method for this.
  DKProperty *p = [[DKProperty alloc] initWithDBusSignature: "s"
                                           accessAttributes: @"readwrite"
                                                       name: @"foo"
                                                     parent: nil];
  NSXMLNode *n = [p XMLNode];
  NSString *nodeString = [n XMLString];
  UKNotNil(n);
  UKTrue([@"<property name=\"foo\" type=\"s\" access=\"readwrite\"/>" isEqualToString: nodeString]
    || [@"<property name=\"foo\" type=\"s\" access=\"readwrite\"></property>" isEqualToString: nodeString]);
}
@end
