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
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>

#import "DKArgument.h"
#import "DKMethod.h"

#import "DKProxy+Private.h"

#include <dbus/dbus.h>
#include <stdint.h>
#include <string.h>

@implementation DKMethod

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
  inArgs = [NSMutableArray new];
  outArgs = [NSMutableArray new];
  return self;
}

- (const char*) returnTypeBoxed: (BOOL)doBox
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

- (const char*) argumentTypeAtIndex: (NSUInteger)index
                              boxed: (BOOL)doBox
{
  if (YES == doBox)
  {
    return @encode(id);
  }
  else if (index < [inArgs count])
  {
    return [[inArgs objectAtIndex: index] unboxedObjCTypeChar];
  }
  return NULL;
}

- (BOOL) isEqualToMethodSignature: (NSMethodSignature*)methodSignature
                            boxed: (BOOL)isBoxed
{
  return [methodSignature isEqual: [self methodSignatureBoxed: isBoxed]];
}

- (NSInteger)boxingStateForArgumentAtIndex: (NSUInteger)argIndex
                       fromMethodSignature: (NSMethodSignature*)aSignature
                                   atIndex: (NSUInteger)sigIndex
{
  NSUInteger argCount = [inArgs count];
  if (argIndex < argCount)
  {
    const char* typeFromSig = [aSignature getArgumentTypeAtIndex: sigIndex];
    const char* boxedType = @encode(id);
    const char *unboxedTypeFromDBus = [[inArgs objectAtIndex: argIndex] unboxedObjCTypeChar];
    BOOL boxedMatch = NO;
    BOOL unboxedMatch = NO;
    if ((typeFromSig == NULL) || (unboxedTypeFromDBus == NULL))
    {
      return DK_ARGUMENT_INVALID;
    }
    boxedMatch = (0 == strcmp(typeFromSig, boxedType));
    if (NO == boxedMatch)
    {
      unboxedMatch = (0 == strcmp(typeFromSig, unboxedTypeFromDBus));
      if (unboxedMatch)
      {
	return DK_ARGUMENT_UNBOXED;
      }
    }
    else
    {
      return DK_ARGUMENT_BOXED;
    }
  }
  return DK_ARGUMENT_INVALID;
}


- (NSInteger)boxingStateForArgumentAtIndex: (NSUInteger)argIndex
                       fromMethodSignature: (NSMethodSignature*)aSignature
{
  // Add an offest to accomodate self and _cmd
  return [self boxingStateForArgumentAtIndex: argIndex
                         fromMethodSignature: aSignature
                                     atIndex: (argIndex + 2)];
}

- (NSInteger)boxingStateForReturnValueFromMethodSignature: (NSMethodSignature*)aSignature
{
  const char* sigReturn = [aSignature methodReturnType];
  BOOL boxedReturnMatch = (0 == strcmp(sigReturn, [self returnTypeBoxed: YES]));
  BOOL unboxedReturnMatch = NO;
  if (boxedReturnMatch)
  {
    return DK_ARGUMENT_BOXED;
  }

  unboxedReturnMatch = (0 == strcmp(sigReturn, [self returnTypeBoxed: NO]));
  if (unboxedReturnMatch)
  {
    return DK_ARGUMENT_UNBOXED;
  }

  return DK_ARGUMENT_INVALID;
}
/**
 * Checks whether it is valid to use the receiver to handle an invocation with
 * the specified method signature, no matter whether the boxed or non-boxed
 * version of an argument is used.
 */
- (BOOL) isValidForMethodSignature: (NSMethodSignature*)aSignature
{
  NSUInteger argIndex = 0;
  NSUInteger argCount = [inArgs count];

  // Subtract 2 to account for self and _cmd in the NSMethodSignature.
  if (argCount != ([aSignature numberOfArguments] - 2))
  {
    return NO;
  }

  if (DK_ARGUMENT_INVALID == [self boxingStateForReturnValueFromMethodSignature: aSignature])
  {
    return NO;
  }

  while (argIndex < argCount)
  {
    NSInteger boxingState = [self boxingStateForArgumentAtIndex: argIndex
                                            fromMethodSignature: aSignature];
    if (DK_ARGUMENT_INVALID == boxingState)
    {
      return NO;
    }
    argIndex++;
  }

  // We passed all checks and can use the method for the given signature:
  return YES;
}

- (const char*)objCTypesBoxed: (BOOL)doBox
{
  /* Type-encodings are as follows:
   * <return-type><arg-frame length><type/offset pairs>
   * Nothing uses the frame length/offset information, though. So we can have a
   * less paranoid stance on the offsets and sizes and spare ourselves the work
   * of generating them.
   */

  // Initial type string containing self and _cmd.
  NSMutableString *typeString = [[NSMutableString alloc] initWithFormat: @"@0:%d", sizeof(id)];
  NSUInteger offset = sizeof(id) + sizeof(SEL);
  NSString *returnValue = nil;
  NSEnumerator *en = [inArgs objectEnumerator];
  DKArgument *arg = nil;

  while (nil != (arg = [en nextObject]))
  {
    const char *typeChar;
    if (doBox)
    {
      typeChar = @encode(id);
    }
    else
    {
      typeChar = [arg unboxedObjCTypeChar];
    }

    [typeString appendFormat: @"%s%d", typeChar, offset];

    if (doBox)
    {
      offset = offset + sizeof(id);
    }
    else
    {
      offset = offset + [arg unboxedObjCTypeSize];
    }
  }

  returnValue = [NSString stringWithFormat: @"%s%d%@", [self returnTypeBoxed: doBox],
    offset,
    typeString];
  [typeString release];
  NSDebugMLog(@"Generated Obj-C type string: %@", returnValue);
  return [returnValue UTF8String];
}

- (NSMethodSignature*) methodSignatureBoxed: (BOOL)doBox
{
  return [NSMethodSignature signatureWithObjCTypes: [self objCTypesBoxed: doBox]];
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

  if ((direction == nil) || [direction isEqualToString: DKArgumentDirectionIn])
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
  if ([parent respondsToSelector: @selector(name)])
  {
    return [parent name];
  }
  return nil;
}

- (BOOL) isDeprecated
{
  return [[annotations valueForKey: @"org.freedesktop.DBus.Deprecated"] isEqualToString: @"true"];
}

- (BOOL) isOneway
{
  return [[annotations valueForKey: @"org.freedesktop.DBus.Method.NoReply"] isEqualToString: @"true"];
}


- (void) unmarshallReturnValueFromIterator: (DBusMessageIter*)iter
                            intoInvocation: (NSInvocation*)inv
{
  NSUInteger numArgs = [outArgs count];
  NSMethodSignature *sig = [inv methodSignature];
  BOOL doBox = YES;
  NSInteger boxingState = [self boxingStateForReturnValueFromMethodSignature: sig];

  // Make sure the return value is boxable
  NSAssert1((DK_ARGUMENT_INVALID != boxingState),
    @"The return value cannot be boxed into invocation with signature %@.",
    sig);

  // If it is not DK_ARGUMENT_INVALID, it leaves 0 and 1 as possible states:
  doBox = (BOOL)boxingState;

  if (0 == numArgs)
  {
    // Void return type, we retrun.
    return;
  }
  else if (1 == numArgs)
  {
    // Pass the iterator and the invocation to the argument, index -1 indicates
    // the return value.
    [[outArgs objectAtIndex: 0] unmarshallFromIterator: iter
                                        intoInvocation: inv
                                               atIndex: -1
                                                boxing: doBox];
  }
  else
  {
    NSMutableArray *returnValues = [NSMutableArray array];
    NSUInteger index = 0;
    NSNull *theNull = [NSNull null];
    while (index < numArgs)
    {
      // We can only support objects here, so we always get the boxed value
      id object = [[outArgs objectAtIndex: index] unmarshalledObjectFromIterator: iter];

      // Do not try to add nil objects
      if (nil == object)
      {
	object = theNull;
      }
      [returnValues addObject: object];

      /*
       * Proceed to the next value in the message, but raise an exception if
       * we are missing some.
       */
      if (NO == (BOOL)dbus_message_iter_next(iter))
      {
        [NSException raise: @"DKMethodUnmarshallingException"
                    format: @"D-Bus message too short when unmarshalling return value for '%@'.",
	  name];
      }
      index++;
    }
    [inv setReturnValue: &returnValues];
  }

}

- (void) marshallReturnValueFromInvocation: (NSInvocation*)inv
                              intoIterator: (DBusMessageIter*)iter
{
  NSUInteger numArgs = [outArgs count];
  NSMethodSignature *sig = [inv methodSignature];
  BOOL doBox = YES;
  NSInteger boxingState = [self boxingStateForReturnValueFromMethodSignature: sig];

  // Make sure the return value is boxable
  NSAssert1(DK_ARGUMENT_INVALID != boxingState,
    @"The return value cannot be boxed into invocation with signature %@.",
    sig);

  // If it is not DK_ARGUMENT_INVALID, it leaves 0 and 1 as possible states:
  doBox = (BOOL)boxingState;

  if (0 == numArgs)
  {
    return;
  }
  else if (1 == numArgs)
  {
    [[outArgs objectAtIndex: 0] marshallArgumentAtIndex: -1
                                         fromInvocation: inv
                                           intoIterator: iter
                                                 boxing: doBox];
  }
  else
  {
    /*
     * For D-Bus methods with multiple out-direction arguments
     * the caller will have stored the individual values as objects in an
     * array.
     */
    NSArray *retVal = nil;
    NSUInteger retCount = 0;
    NSInteger index = 0;

    // Make sure the method did return an object:
    NSAssert2((0 == strcmp(@encode(id), [sig methodReturnType])),
      @"Invalid return value when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    [inv getReturnValue: &retVal];

    // Make sure that it responds to the needed selectors:
    NSAssert2(([retVal respondsToSelector: @selector(objectAtIndex:)]
      && [retVal respondsToSelector: @selector(count)]),
      @"Expected array return value when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    retCount = [retVal count];

    // Make sure that the number of argument matches:
    NSAssert2((retCount == [outArgs count]),
      @"Argument number mismatch when constucting D-Bus reply for '%@' on %@",
      NSStringFromSelector([inv selector]),
      [inv target]);

    // Marshall them in order:
    while (index < retCount)
    {
      [[outArgs objectAtIndex: index] marshallObject: [retVal objectAtIndex: index]
                                        intoIterator: iter];
      index++;
    }
  }
}

- (void)unmarshallArgumentsFromIterator: (DBusMessageIter*)iter
                         intoInvocation: (NSInvocation*)inv
{
  NSUInteger numArgs = [inArgs count];
  // Arguments start at index 2 (i.e. after self and _cmd)
  NSUInteger index = 2;
  NSMethodSignature *sig = [inv methodSignature];
  while (index < (numArgs +2))
  {
    NSUInteger argIndex = index - 2;
    BOOL doBox = YES;
    NSInteger boxingState = [self boxingStateForArgumentAtIndex: argIndex
                                            fromMethodSignature: sig];
    NSAssert1((DK_ARGUMENT_INVALID != boxingState),
      @"Argument cannot be boxed into invocation with signature %@.",
      sig);

    doBox = (BOOL)boxingState;
    // Let the arguments umarshall themselves into the invocation
    [[inArgs objectAtIndex: argIndex] unmarshallFromIterator: iter
                                              intoInvocation: inv
                                                     atIndex: index
                                                      boxing: doBox];
    /*
     * Proceed to the next value in the message, but raise an exception if
     * we are missing some arguments.
     */
    if (NO == (BOOL)dbus_message_iter_next(iter))
    {
      [NSException raise: @"DKMethodUnmarshallingException"
                  format: @"D-Bus message too short when unmarshalling arguments for invocation of '%@' on '%@'.",
        NSStringFromSelector([inv selector]),
        [inv target]];
    }
    index++;
  }
}

- (void) marshallArgumentsFromInvocation: (NSInvocation*)inv
                            intoIterator: (DBusMessageIter*)iter
{
  // Start with index 2 to get the proper arguments
  NSUInteger index = 2;
  DKArgument *argument = nil;
  NSEnumerator *argEnum = [inArgs objectEnumerator];
  NSMethodSignature *sig = [inv methodSignature];

  NSAssert1(([inArgs count] == ([[inv methodSignature] numberOfArguments] -2)),
    @"Argument number mismatch when constructing D-Bus call for '%@'", name);

  while (nil != (argument = [argEnum nextObject]))
  {
    BOOL doBox = YES;
    NSInteger boxingState = [self boxingStateForArgumentAtIndex: (index -2 )
                                            fromMethodSignature: sig];
    NSAssert1((DK_ARGUMENT_INVALID != boxingState),
      @"Argument cannot be boxed into invocation with signature %@.",
      sig);

    doBox = (BOOL)boxingState;

    [argument marshallArgumentAtIndex: index
                       fromInvocation: inv
                         intoIterator: iter
                               boxing: doBox];
  index++;
  }
}

- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
   	            messageType: (int)type
{
   if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
   {
     // For method returns, we are interested in the return value.
     [self unmarshallReturnValueFromIterator: iter
                              intoInvocation: inv];
   }
   else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
   {
     // For method calls, we want to construct the invocation from the
     // arguments.
     [self unmarshallArgumentsFromIterator: iter
                            intoInvocation: inv];
   }
}

- (void)marshallFromInvocation: (NSInvocation*)inv
                  intoIterator: (DBusMessageIter*)iter
                   messageType: (int)type
{
  if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
    // If we are constructing a method return message, we want to obtain the
    // return value.
    [self marshallReturnValueFromInvocation: inv
                               intoIterator: iter];
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    // If we are constructing a method call, we want to marshall the arguments
    [self marshallArgumentsFromInvocation: inv
                             intoIterator: iter];
  }
}
- (NSString*)methodDeclaration
{
  NSMutableString *declaration = [NSMutableString stringWithString: @"- "];
  NSArray *components = nil;
  NSString *returnType = nil;
  NSUInteger outCount = [outArgs count];
  NSUInteger inCount = [inArgs count];
  NSUInteger inIndex = 0;
  NSEnumerator *argEnum = nil;
  DKArgument *arg = nil;

  if (0 == inCount)
  {
    components = [NSArray arrayWithObject: [self selectorString]];
  }
  else
  {
    components = [[self selectorString] componentsSeparatedByString: @":"];
  }

  NSAssert2(([components count] == (inCount + 1)), @"Invalid selector '%@' for method '%@'.",
    [self selectorString],
    name);

  if (0 == outCount)
  {
    if ([self isOneway])
    {
      returnType = @"oneway void";
    }
    else
    {
      returnType = @"void";
    }

  }
  else if (outCount > 1)
  {
    returnType = @"NSArray*";
  }
  else
  {
    Class retClass = [(DKArgument*)[outArgs objectAtIndex: 0] objCEquivalent];
    if (Nil == retClass)
    {
      returnType = @"id";
    }
    else
    {
      returnType = [NSString stringWithFormat: @"%@*", NSStringFromClass(retClass)];
    }
  }

  [declaration appendFormat: @"(%@)", returnType];

  if (0 == inCount)
  {
    // If we have no arguments, we add the selector string here, because we will
    // not run the loop in this case.
    [declaration appendFormat: @"%@ ", [components objectAtIndex: 0]];
  }
  else
  {
    argEnum = [inArgs objectEnumerator];
    while (nil != (arg = [argEnum nextObject]))
    {
      NSString *argType = @"id";
      NSString *argName = [arg name];
      Class theClass = [arg objCEquivalent];
      if (theClass != Nil)
      {
        argType = [NSStringFromClass(theClass) stringByAppendingString: @"*"];
      }

      if (nil == argName)
      {
        argName = [NSString stringWithFormat: @"argument%ld", inIndex];
      }
      [declaration appendFormat:@"%@: (%@)%@ ",
        [components objectAtIndex: inIndex],
        argType,
        argName];
      inIndex++;
    }
  }
  if ([self isDeprecated])
  {
    [declaration appendString: @"__attribute__((deprecated));"];
  }
  else
  {
    [declaration replaceCharactersInRange: NSMakeRange(([declaration length] - 1), 1)
                               withString: @";"];
  }
  return declaration;
}

- (NSString*)annotationValueForKey: (NSString*)key
{
  NSString *value = [super annotationValueForKey: key];
  // Perform validation whether we can use this selector string for the method,
  // viz. determine whether it has the right number of colons (':').
  if ([@"org.gnustep.objc.selector" isEqualToString: key])
  {
    const char* selectorString = [value UTF8String];
    NSUInteger len = [value length];
    NSUInteger i = 0;
    NSUInteger expectedCount = [inArgs count];
    NSUInteger actualCount = 0;
    for (i = 0; i < len; i++)
    {
      if (':' == selectorString[i])
      {
	actualCount++;
      }
      if (actualCount > expectedCount)
      {
	return nil;
      }
    }
    if (actualCount != expectedCount)
    {
      return nil;
    }
  }

  return value;
}
- (NSString*)selectorString
{
  NSString *selectorString = [self annotationValueForKey: @"org.gnustep.objc.selector"];
  if (nil == selectorString)
  {
    // We generate a selector string from the method name by appending the
    // correct number of colons
    NSUInteger newLength = [name length] + [inArgs count];
    selectorString = [name stringByPaddingToLength: newLength
                                        withString: @":"
                                   startingAtIndex: 0];
  }
  return selectorString;
}

- (void)setOutArgs: (NSMutableArray*)newOut
{
  ASSIGN(outArgs, newOut);
  [outArgs makeObjectsPerformSelector: @selector(setParent:) withObject: self];
}

- (void)setInArgs: (NSMutableArray*)newIn
{
  ASSIGN(inArgs, newIn);
  [inArgs makeObjectsPerformSelector: @selector(setParent:) withObject: self];
}

- (id)copyWithZone: (NSZone*)zone
{
  DKMethod *newNode = [super copyWithZone: zone];
  NSMutableArray *newIn = nil;
  NSMutableArray *newOut = nil;
  newIn = [[NSMutableArray allocWithZone: zone] initWithArray: inArgs
                                                    copyItems: YES];
  newOut = [[NSMutableArray allocWithZone: zone] initWithArray: outArgs
                                                     copyItems: YES];
  [newNode setOutArgs: newOut];
  [newNode setInArgs: newIn];
  [newOut release];
  [newIn release];
  return newNode;
}

- (void)dealloc
{
  [inArgs release];
  [outArgs release];
  [super dealloc];
}
@end
