/** Implementation of DKMethod class for encapsulating D-Bus methods.
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

   <title>DKMethod class reference</title>
   */
#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>

#import "DKArgument.h"
#import "DKMethod.h"

#include <stdint.h>


static BOOL DKMethodSignaturesParanoid = NO;
DKMethod *_DKMethodIntrospect;

@implementation DKMethod

+ (void)initialize
{
  if ([DKMethod class] == self)
  {
    DKArgument *xmlOutArg = nil;
    _DKMethodIntrospect = [[DKMethod alloc] initWithMethodName: @"Introspect"
                                                     interface: @"org.freedesktop.DBus.Introspectable"
                                                        parent: nil];
    xmlOutArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                     name: @"data"
                                                   parent: _DKMethodIntrospect];
    [_DKMethodIntrospect addArgument: xmlOutArg
                           direction: DKArgumentDirectionOut];
    [xmlOutArg release];
  }
}

- (id) initWithMethodName: (NSString*)aName
                interface: (NSString*)anInterface
                   parent: (id)aParent
{
  if (nil == (self = [super init]))
  {
    return nil;
  }
  ASSIGNCOPY(methodName,aName);
  ASSIGNCOPY(interface,anInterface);
  inArgs = [NSMutableArray new];
  outArgs = [NSMutableArray new];
  parent = aParent;
  return self;
}

- (char*) returnTypeBoxed: (BOOL)doBox
{
  NSUInteger count = [outArgs count];
  if (count == 0)
  {
    // No return value, void method.
    return @encode(void);
  }
  else if ((count == 1) && (NO == doBox))
  {
    // One argument, and we don't want boxing
    return [(DKArgument*)[outArgs objectAtIndex: 0] unboxedObjCTypeChar];
  }
  else
  {
    // Multiple return value, or we want boxing anyhow.
    return @encode(id);
  }
}

- (NSMethodSignature*) methodSignatureBoxed: (BOOL)doBox
{
  /* Type-encodings are as follows:
   * <return-type><arg-frame length><type/offset pairs>
   * Nothing uses the frame length/offset information, though. So we can have a
   * less paranoid stance on the offsets and sizes and spare ourselves the work
   * of generating  them. (Unless someone sets DKMethodSignaturesParanoid.)
   */

  NSUInteger offset = 0;

  // Initial type string containing self and _cmd.
  NSMutableString *typeString = [[NSMutableString alloc] initWithFormat: @"@0:%d", sizeof(id)];
  NSString *fullString = nil;
  NSMethodSignature *ret = nil;

  NSEnumerator *en = [inArgs objectEnumerator];
  DKArgument *arg = nil;

  // If paranoid mode is defined, generate proper signatures.
  if (DKMethodSignaturesParanoid)
  {
    offset = sizeof(id) + sizeof(SEL);
  }
  while (nil != (arg = [en nextObject]))
  {
    char *typeChar;
    if (doBox)
    {
      typeChar = @encode(id);
    }
    else
    {
      typeChar = [arg unboxedObjCTypeChar];
    }

    [typeString appendFormat: @"%s%d", typeChar, offset];
    if (DKMethodSignaturesParanoid)
    {
      NSUInteger thisArgSize = 0;
      if (doBox)
      {
	thisArgSize = sizeof(id);
      }
      else
      {
	thisArgSize = [arg unboxedObjCTypeSize];
      }
      offset += thisArgSize;
    }
  }

  fullString = [[NSString alloc] initWithFormat: @"%s%d%@", [self returnTypeBoxed: doBox],
    offset,
    typeString];
  [typeString release];
  NSDebugMLog(@"Generated type signature '%@' for method '%@'.", fullString, methodName);
  ret = [NSMethodSignature signatureWithObjCTypes: [fullString UTF8String]];
  [fullString release];
  return ret;
}

- (NSMethodSignature*) methodSignature
{
  return [self methodSignatureBoxed: YES];
}

- (DKArgument*)DKArgumentAtIndex: (NSInteger)index
{
  NSArray *args = nil;
  if (index < 0)
  {
    args = outArgs;
    // Convert to positive integer:
    index *= -1;
    // Decrement to start with 0:
    index--;
  }
  else
  {
    args = inArgs;
  }

  if (index < [args count])
  {
    return [args objectAtIndex: index];
  }
  return nil;
}

- (void)addArgument: (DKArgument*)argument
          direction: (NSString*)direction
{
  if (nil == argument)
  {
    NSDebugMLog(@"Ignoring nil argument");
    return;
  }

  if ([direction isEqualToString: DKArgumentDirectionIn])
  {
    [inArgs addObject: argument];
  }
  else if ([direction isEqualToString: DKArgumentDirectionOut])
  {
    [outArgs addObject: argument];
  }
  else
  {
    NSDebugMLog(@"Ignoring argument with unkown direction '%@'.", direction);
  }
}

- (NSString*) interface
{
  return interface;
}
- (NSString*) methodName
{
  return methodName;
}

- (id) parent
{
  return parent;
}
- (void) setAnnotationValue: (id)value
                     forKey: (NSString*)key
{
  if ((nil == value) || (nil == key))
  {
    NSDebugMLog(@"Ignored invalid annotation key value pair");
  }
  if (nil == annotations)
  {
    NSDebugMLog(@"Lazily initializing annotation dictionary");
    annotations = [NSMutableDictionary new];
  }

  [annotations setValue: value
                 forKey: key];
  NSDebugMLog(@"Added value %@ for key %@", value, key);
}

/**
 * Returns the value of the specified annotation key.
 */
- (id) annotationValueForKey: (NSString*)key
{
  return [annotations valueForKey: key];
}

- (BOOL) isDeprecated
{
  return [[annotations valueForKey: @"org.freedesktop.DBus.Deprecated"] isEqualToString: @"true"];
}
- (NSString*)methodDeclaration
{
  NSMutableString *declaration = [NSMutableString stringWithString: @"- "];
  NSString *returnType = nil;
  NSUInteger outCount = [outArgs count];
  NSEnumerator *argEnum = nil;
  DKArgument *arg = nil;
  NSUInteger count = 0;

  if (0 == outCount)
  {
    returnType = @"void";
  }
  else if (outCount > 1)
  {
    returnType = @"NSArray*";
  }
  else
  {
    returnType = [NSString stringWithFormat: @"%@*",
      NSStringFromClass([(DKArgument*)[outArgs objectAtIndex: 0] objCEquivalent])];
  }

  [declaration appendFormat: @"(%@) %@", returnType, methodName];

  argEnum = [inArgs objectEnumerator];
  while (nil != (arg = [argEnum nextObject]))
  {
    NSString *argType = @"id";
    NSString *name = [arg name];
    Class theClass = [arg objCEquivalent];
    if (theClass != Nil)
    {
      argType = [NSStringFromClass(theClass) stringByAppendingString: @"*"];
    }

    if (nil == name)
    {
      name = [[NSString alloc] initWithFormat: @"argument%ld", count];
    }
    [declaration appendFormat:@": (%@)%@ ", argType, name];
    [name release];
    count++;
  }
  if ([self isDeprecated])
  {
    [declaration appendString: @"__attribute__((deprecated));"];
  }
  else
  {
    [declaration replaceCharactersInRange: NSMakeRange(([declaration length]), 0)
                               withString: @";"];
  }
  return declaration;
}


- (void)dealloc
{
  parent = nil;
  [methodName release];
  [interface release];
  [inArgs release];
  [outArgs release];
  [annotations release];
  [super dealloc];
}
@end
