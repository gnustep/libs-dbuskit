/** Implementation DKPorpertyMethod and subclasses.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: September 2010

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

#import "DKPropertyMethod.h"
#import "DKArgument.h"
#import "DKProperty.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#include <string.h>
#include <dbus/dbus.h>

@implementation DKPropertyMethod

- (id)initWithName: (NSString*)aName
            parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }

  if (NO == [aParent isKindOfClass: [DKProperty class]])
  {
    NSWarnMLog(@"Not creating property method for non-property parent.");
    [self release];
    return nil;
  }

  return self;
}

- (NSString*)interface
{
  return @"org.freedesktop.DBus.Properties";
}
@end

@implementation DKPropertyAccessor

- (id)initWithProperty: (DKProperty*)aProperty
{
  DKArgument *interfaceArg = nil;
  DKArgument *propertyNameArg = nil;
  DKArgument *retValArg = nil;
  if (nil == (self = [super initWithName: @"Get"
                                  parent: aProperty]))
  {
    return nil;
  }

  /*
   * Create the argument for the Get() method, making sure that we don't leak
   * memory in the process.
   */
  NS_DURING
  {
    interfaceArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                        name: @"interface_name"
                                                      parent: self];
    [self addArgument: interfaceArg
            direction: DKArgumentDirectionIn];
    NS_DURING
    {
      propertyNameArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                             name: @"property_name"
                                                           parent: self];

    [self addArgument: propertyNameArg
            direction: DKArgumentDirectionIn];

      NS_DURING
      {
        retValArg = [[(DKProperty*)parent type] copy];
	[retValArg setParent: self];
	[self addArgument: retValArg
	        direction: DKArgumentDirectionOut];
      }
      NS_HANDLER
      {
        [retValArg release];
	[localException raise];
      }
      NS_ENDHANDLER
    }
    NS_HANDLER
    {
      [propertyNameArg release];
      [localException raise];
    }
    NS_ENDHANDLER
  }
  NS_HANDLER
  {
    [interfaceArg release];
    [localException raise];
  }
  NS_ENDHANDLER
  [interfaceArg release];
  [propertyNameArg release];
  [retValArg release];

  return self;
}

- (NSString*)selectorString
{
  return [parent name];
}

- (const char*)objCTypesBoxed: (BOOL)doBox
{
  return [[NSString stringWithFormat: @"%s%d@0:%d", [self returnTypeBoxed: doBox],
    (sizeof(id) + sizeof(SEL)),
    sizeof(id)] UTF8String];
}

- (BOOL) isValidForMethodSignature: (NSMethodSignature*)aSignature
{
  /* Accessor methods take no arguments except for self and _cmd: */
  if (2 != [aSignature numberOfArguments])
  {
    return NO;
  }

  /* Only whether we can safely box/unbox the return value: */
  if (DK_ARGUMENT_INVALID == [self boxingStateForReturnValueFromMethodSignature: aSignature])
  {
    return NO;
  }
  return YES;
}

- (void)marshallFromInvocation: (NSInvocation*)inv
                  intoIterator: (DBusMessageIter*)iter
		   messageType: (int)type
{
  /*
   * For returns, we simply wrap the value from the invocation in an variant
   * type container.
   */
  if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
    DBusMessageIter subIter;
    const char *sig = [[(DKArgument*)[outArgs objectAtIndex: 0] DBusTypeSignature] UTF8String];

    /* Open the container and check for OOM: */
    if (NO == (BOOL)dbus_message_iter_open_container(iter,
      DBUS_TYPE_VARIANT,
      sig,
      &subIter))
    {
      [NSException raise: @"DKArgumentMarshallingException"
                  format: @"Out of memory when marshalling argument."];
    }

    /* Let super do the marshalling: */
    [super marshallFromInvocation: inv
                     intoIterator: &subIter
                      messageType: type];

    /* Close the container and check for OOM: */
    if (NO == (BOOL)dbus_message_iter_close_container(iter, &subIter))
    {
      [NSException raise: @"DKArgumentMarshallingException"
                  format: @"Out of memory when marshalling argument."];
    }
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    /* For calls, we need to construct the arguments manually: */
    // marshall interface name from the parent
    [(DKArgument*)[inArgs objectAtIndex: 0] marshallObject: [(DKProperty*)parent interface]
                                                intoIterator: iter];
    // marshall property name from the parent
    [(DKArgument*)[inArgs objectAtIndex: 1] marshallObject: [(DKProperty*)parent name]
                                                intoIterator: iter];
  }
}

- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
		    messageType: (int)type
{
  if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    /* If a getter is being called from D-Bus, we do unmarshall any arguments.
     * Those that have been there (interface and property name, will already
     * have been deserialized by the dispatcher in order to find this method.
     * Hence, we just return;
     */
     return;
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
    DBusMessageIter subIter;
    DKArgument *returnArg = [outArgs objectAtIndex: 0];
    char *actualSignature = NULL;

    // Make sure we are processing a variant:
    NSAssert((DBUS_TYPE_VARIANT == dbus_message_iter_get_arg_type(iter)),
        @"Type mismatch between introspection data and D-Bus message.");

    // Recurse into the variant:
    dbus_message_iter_recurse(iter,&subIter);

    // Find the type:
    actualSignature = dbus_message_iter_get_signature(&subIter);

    // Make sure that we find what we expect:
    NS_DURING
    {
      NSAssert3((0 == strcmp(actualSignature, [[returnArg DBusTypeSignature] UTF8String])),
        @"Type mismatch for property %@, expected %@, got %s.",
        parent,
        [returnArg DBusTypeSignature],
        actualSignature);
    }
    NS_HANDLER
    {
      dbus_free(actualSignature);
      [localException raise];
    }
    NS_ENDHANDLER
    dbus_free(actualSignature);

    // Let the superclass implementation do the work:
    [super unmarshallFromIterator: &subIter
                   intoInvocation: inv
                      messageType: type];
  }
}

- (NSArray*)userVisibleArguments
{
  return nil;
}

- (NSUInteger)userVisibleArgumentCount
{
  return 0;
}
@end

@implementation DKPropertyMutator

- (id)initWithProperty: (DKProperty*)aProperty
{
  DKArgument *interfaceArg = nil;
  DKArgument *propertyNameArg = nil;
  DKArgument *newValArg = nil;
  if (nil == (self = [super initWithName: @"Set"
                                  parent: aProperty]))
  {
    return nil;
  }

  /*
   * Create the argument for the Get() method, making sure that we don't leak
   * memory in the process.
   */
  NS_DURING
  {
    interfaceArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                        name: @"interface_name"
                                                      parent: self];
    [self addArgument: interfaceArg
            direction: DKArgumentDirectionIn];
    NS_DURING
    {
      propertyNameArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                             name: @"property_name"
                                                           parent: self];

    [self addArgument: propertyNameArg
            direction: DKArgumentDirectionIn];

      NS_DURING
      {
        newValArg = [[(DKProperty*)parent type] copy];
	[newValArg setParent: self];
	[self addArgument: newValArg
	        direction: DKArgumentDirectionIn];
      }
      NS_HANDLER
      {
        [newValArg release];
	[localException raise];
      }
      NS_ENDHANDLER
    }
    NS_HANDLER
    {
      [propertyNameArg release];
      [localException raise];
    }
    NS_ENDHANDLER
  }
  NS_HANDLER
  {
    [interfaceArg release];
    [localException raise];
  }
  NS_ENDHANDLER
  [interfaceArg release];
  [propertyNameArg release];
  [newValArg release];

  return self;
}

- (NSString*)selectorString
{
  // Use camelCase:
  NSString *parentName = [parent name];
  NSString *propertyName = [parentName stringByReplacingCharactersInRange: NSMakeRange(0,1)
                                                               withString: [[parentName substringToIndex: 1] capitalizedString]];
  return [NSString stringWithFormat: @"set%@:", propertyName];
}

- (const char*)objCTypesBoxed: (BOOL)doBox
{
  DKArgument *valueArgument = [inArgs objectAtIndex: 2];
  size_t valueSize = 0;
  const char *valueType;
  if (doBox)
  {
    valueSize = sizeof(id);
    valueType = @encode(id);
  }
  else
  {
    valueSize = [valueArgument unboxedObjCTypeSize];
    valueType = [valueArgument unboxedObjCTypeChar];
  }

  return [[NSString stringWithFormat: @"%s%d@0:%d%s%d", @encode(void),
    ((sizeof(id) + sizeof(SEL)) + valueSize),
    sizeof(id),
    valueType,
    (sizeof(id) + sizeof(SEL))] UTF8String];
}

- (BOOL) isValidForMethodSignature: (NSMethodSignature*)aSignature
{
  /* Mutator methods take three arguments (self, _cmd, and the new value) */
  if (3 != [aSignature numberOfArguments])
  {
    return NO;
  }

  /*
   * Only check whether we can safely box/unbox the new value. For this check,
   * we need to offset the hidden arguments representing interface and property
   * name.
   */
  if (DK_ARGUMENT_INVALID == [self boxingStateForArgumentAtIndex: 2
                                             fromMethodSignature: aSignature
					                 atIndex: 2])
  {
    return NO;
  }
  return YES;
}

- (void)marshallFromInvocation: (NSInvocation*)inv
                  intoIterator: (DBusMessageIter*)iter
		   messageType: (int)type
{
  /*
   * If we are sending a return message, we do nothing because the setter
   * returns void.
   */
  if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
    return;
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    /* For calls, we need to construct the arguments manually: */
    DBusMessageIter subIter;
    DKArgument *newValArg = [inArgs objectAtIndex: 2];
    NSMethodSignature *objCSig = [inv methodSignature];
    const char *DBusSig = [[newValArg DBusTypeSignature] UTF8String];
    BOOL doBox = YES;
    NSInteger boxingState = [self boxingStateForArgumentAtIndex: 2
                                            fromMethodSignature: objCSig
                                                        atIndex: 2];

    // Sanity check: Abort if there is a type mismatch between the argument and
    // the invocation.
    NSAssert1((DK_ARGUMENT_INVALID != boxingState),
      @"Type mismatch when marshalling invocation '%@' into org.freedesktop.DBus.Properties.Set() method call.",
      inv);

    // marshall interface name from the parent
    [(DKArgument*)[inArgs objectAtIndex: 0] marshallObject: [(DKProperty*)parent interface]
                                              intoIterator: iter];
    // marshall property name from the parent
    [(DKArgument*)[inArgs objectAtIndex: 1] marshallObject: [(DKProperty*)parent name]
                                              intoIterator: iter];

    /* Open the container and check for OOM: */
    if (NO == (BOOL)dbus_message_iter_open_container(iter,
      DBUS_TYPE_VARIANT,
      DBusSig,
      &subIter))
    {
      [NSException raise: @"DKArgumentMarshallingException"
                  format: @"Out of memory when marshalling argument."];
    }

    /* Set the boxing state */
    if (DK_ARGUMENT_BOXED == boxingState)
    {
      doBox = YES;
    }
    else if (DK_ARGUMENT_UNBOXED == boxingState)
    {
      doBox = NO;
    }

    /*
     * Do the marshalling of the actual argument. (the index refers to the
     * position of the argument within the invocation)
     */
    [newValArg marshallArgumentAtIndex: 2
                        fromInvocation: inv
                          intoIterator: &subIter
                                boxing: doBox];
    /* Close the container and check for OOM: */
    if (NO == (BOOL)dbus_message_iter_close_container(iter, &subIter))
    {
      [NSException raise: @"DKArgumentMarshallingException"
                  format: @"Out of memory when marshalling argument."];
    }
  }
}

- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
		    messageType: (int)type
{
  if (DBUS_MESSAGE_TYPE_METHOD_RETURN == type)
  {
     /*
      * We don't have any return arguments and can simply return.
      */
     return;
  }
  else if (DBUS_MESSAGE_TYPE_METHOD_CALL == type)
  {
    DBusMessageIter subIter;
    DKArgument *newValArg = [inArgs objectAtIndex: 2];
    char *actualSignature = NULL;
    NSMethodSignature *objCSig = [inv methodSignature];
    BOOL doBox = YES;
    NSInteger boxingState = [self boxingStateForArgumentAtIndex: 2
                                            fromMethodSignature: objCSig
                                                        atIndex: 2];

    // Sanity check: Abort if there is a type mismatch between the argument and
    // the invocation.
    NSAssert2((DK_ARGUMENT_INVALID != boxingState),
      @"Type mismatch when unmarshalling Set() for property '%@' into invocation '%@'.",
      parent,
      inv);

    // Make sure we are processing a variant:
    NSAssert((DBUS_TYPE_VARIANT == dbus_message_iter_get_arg_type(iter)),
        @"Type mismatch between introspection data and D-Bus message.");

    // Recurse into the variant:
    dbus_message_iter_recurse(iter,&subIter);

    // Find the type:
    actualSignature = dbus_message_iter_get_signature(&subIter);

    // Make sure that we find what we expect:
    NS_DURING
    {
      NSAssert3((0 == strcmp(actualSignature, [[newValArg DBusTypeSignature] UTF8String])),
        @"Type mismatch for property %@, expected %@, got %s.",
        parent,
        [newValArg DBusTypeSignature],
        actualSignature);
    }
    NS_HANDLER
    {
      dbus_free(actualSignature);
      [localException raise];
    }
    NS_ENDHANDLER
    dbus_free(actualSignature);

    /* Set the boxing state */
    if (DK_ARGUMENT_BOXED == boxingState)
    {
      doBox = YES;
    }
    else if (DK_ARGUMENT_UNBOXED == boxingState)
    {
      doBox = NO;
    }

    // Do the unmarshalling:
    [newValArg unmarshallFromIterator: &subIter
                       intoInvocation: inv
                              atIndex: 2
                               boxing: doBox];
  }
}

- (NSArray*)userVisibleArguments
{
  return [NSArray arrayWithObject: [inArgs objectAtIndex: 2]];
}

- (NSUInteger)userVisibleArgumentCount
{
  return 1;
}
@end
