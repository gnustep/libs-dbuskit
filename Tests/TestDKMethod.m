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

#import "../Source/DKArgument.h"
#import "../Source/DKMethod.h"
#import "../Source/DKInterface.h"
#import "../Source/DKProxy+Private.h"
#import "../Source/DKBoxingUtils.h"

#include <string.h>
@interface TestDKMethod: NSObject <UKTest>
@end

@interface FooTestObject: NSObject
- (char*)doSomeFooThingWith: (NSString*)string;
- (oneway void)neverWaitAbout: (id)someThing;
@end

@implementation FooTestObject

- (char*)doSomeFooThingWith: (NSString*)string
{
	return "foo";
}
- (oneway void)neverWaitAbout: (id)someThing
{
  return;
}
@end

@implementation TestDKMethod
+ (void)initialize
{
  if ([TestDKMethod class] == self)
  {
    // Do this to initialize the global introspection method:
    [DKProxy class];
  }
}

- (void)testInitializerAssignments
{
  NSNull *dummyParent = [NSNull null];
  DKMethod *method = [[DKMethod alloc] initWithName: @"Fooify"
                                             parent: dummyParent];
  UKObjectsEqual(@"Fooify",[method name]);
  UKObjectsEqual(dummyParent, [method parent]);
  [method release];
}

- (void)testBuiltInIntrospectSignatureBoxed
{
  DKMethod *method = [_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)];
  NSMethodSignature *sig = [method methodSignature];
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
  DKMethod *method = [_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)];
  NSMethodSignature *sig = [method methodSignatureBoxed: NO];
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

- (void)testEmitMethodDeclaration
{

  DKMethod *method = [_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)];
  UKObjectsEqual(@"- (NSString*)Introspect;", [method methodDeclaration]);
}

- (void)testReprarentInCopy
{
  DKInterface *new = [_DKInterfaceIntrospectable copy];
  DKMethod *method = [new DBusMethodForSelector: @selector(Introspect)];
  UKNotNil(method);
  UKObjectsEqual(new, [method parent]);
}


- (void)testXMLNode
{
  //We use our builtin introspection method for this.
  DKMethod *m = [_DKInterfaceIntrospectable DBusMethodForSelector: @selector(Introspect)];
  NSXMLNode *n = [m XMLNode];
  UKNotNil(n);
  UKObjectsEqual(@"Introspect", [[(NSXMLElement*)n attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"data", [[(NSXMLElement*)[n childAtIndex: 0] attributeForName: @"name"] stringValue]);
  UKObjectsEqual(@"s", [[(NSXMLElement*)[n childAtIndex: 0] attributeForName: @"type"] stringValue]);
  UKObjectsEqual(@"out", [[(NSXMLElement*)[n childAtIndex: 0] attributeForName: @"direction"] stringValue]);
}

- (void)testSelectorMangling
{
	UKObjectsEqual(@"setObjectForKey",
	  DKMethodNameFromSelector(@selector(setObject:forKey:)));
}


- (void)testMethodFromSelector
{
  DKMethod *m = [DKMethod methodWithTypedObjCSelector:
    method_getName(class_getInstanceMethod([FooTestObject class], @selector(doSomeFooThingWith:)))];
  UKNotNil(m);
  UKIntsEqual(DBUS_TYPE_VARIANT, [[m DKArgumentAtIndex: 0] DBusType]);
  UKIntsEqual(DBUS_TYPE_STRING, [[m DKArgumentAtIndex: -1] DBusType]);
  UKObjectsEqual(@"doSomeFooThingWith:", [m annotationValueForKey: @"org.gnustep.objc.selector"]);
}
@end
