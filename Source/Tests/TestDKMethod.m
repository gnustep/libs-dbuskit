/* Unit tests for DKMethod
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
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <UnitKit/UnitKit.h>

#import "../DKMethod.h"
#include <string.h>
@interface TestDKMethod: NSObject <UKTest>
@end

@implementation TestDKMethod
+ (void)initialize
{
  if ([TestDKMethod class] == self)
  {
    // Do this to initialize the global introspection method:
    [DKMethod class];
  }
}

- (void)testInitializerAssignments
{
  NSNull *dummyParent = [NSNull null];
  DKMethod *method = [[DKMethod alloc] initWithMethodName: @"Fooify"
                interface: @"org.gnustep.fake"
                   parent: dummyParent];
  UKObjectsEqual(@"Fooify",[method methodName]);
  UKObjectsEqual(@"org.gnustep.fake", [method interface]);
  UKObjectsEqual(dummyParent, [method parent]);
  [method release];
}

- (void)testBuiltInIntrospectSignatureBoxed
{
  NSMethodSignature *sig = [_DKMethodIntrospect methodSignature];
  NSUInteger argCount = [sig numberOfArguments];
  UKTrue((0 == strcmp([sig methodReturnType], @encode(id))));
  if (argCount == 2)
  {
    UKPass();
    UKTrue((0 == strcmp([sig getArgumentTypeAtIndex: 0], @encode(id))));
    UKTrue((0 == strcmp([sig getArgumentTypeAtIndex: 1], @encode(SEL))));
  }
  else
  {
    UKFail();
  }
}
- (void)testBuiltInIntrospectSignatureNotBoxed
{
  NSMethodSignature *sig = [_DKMethodIntrospect methodSignatureBoxed: NO];
  NSUInteger argCount = [sig numberOfArguments];
  UKTrue((0 == strcmp([sig methodReturnType], @encode(char*))));
  if (argCount == 2)
  {
    UKPass();
    UKTrue((0 == strcmp([sig getArgumentTypeAtIndex: 0], @encode(id))));
    UKTrue((0 == strcmp([sig getArgumentTypeAtIndex: 1], @encode(SEL))));
  }
  else
  {
    UKFail();
  }
}
@end
