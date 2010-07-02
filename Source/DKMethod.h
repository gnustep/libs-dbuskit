/** Interface for DKMethod class encapsulating D-Bus method information.
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

#import "DKIntrospectionNode.h"
#include <dbus/dbus.h>
@class NSString, NSMutableArray,  NSMethodSignature, DKArgument;
@interface DKMethod: DKIntrospectionNode
{
  NSString *interface;
  NSMutableArray *inArgs;
  NSMutableArray *outArgs;
}

/**
 * Initializes the method description with a name and the corresponding
 * interface. The parent can indicate the proxy/object vendor the method is
 * attached to.
 */
- (id) initWithMethodName: (NSString*)aName
                interface: (NSString*)anInterface
                   parent: (id)parent;


/**
 * Returns the Objective-C type string the method corresponds to. Use doBox to
 * indicate whether the boxed signature is requested.
 */
- (const char*)objCTypesBoxed: (BOOL)doBox;

/**
 * Returns whether the method signature sig matches the signature for this
 * method. Use isBoxed to indicate whether you are interested in the boxed or
 * non-boxed case.
 */
- (BOOL) isEqualToMethodSignature: (NSMethodSignature*)sig
                            boxed: (BOOL)isBoxed;

/**
 * Returns the method signature that the Objective-C type system will use to
 * construct invocations for this method. This will be the boxed representation
 * by default.
 */
- (NSMethodSignature*) methodSignature;

/**
 * DKMethods can return two distinct method signatures: One for the completely
 * boxed variant where every D-Bus type will be boxed by an equivalent class on
 * the Objective-C side. The other with minimal boxing (only variable/containar
 * types will be boxed) will return the plain C types corresponding to the D-Bus
 * types. If you want that variant. Pass NO for the doBox argument.
 */
- (NSMethodSignature*) methodSignatureBoxed: (BOOL)doBox;

/**
 * Returns the DKArgument at the specific index. Positive integers denote input
 * arugments, negative integers denote output arguments (offset by one).
 */
- (DKArgument*)DKArgumentAtIndex: (NSInteger)index;

/**
 * Returns the interface associated with the methods.
 */
- (NSString*) interface;


/**
 * Returns whether a reply is expected for this message.
 */
- (BOOL) isOneway;

/**
 * Returns whether D-Bus metadata indicates that the method has been deprecated.
 */
- (BOOL) isDeprecated;

/**
 * Returns an Objective-C method declaration for the D-Bus method.
 */
- (NSString*)methodDeclaration;

/**
 * Adds an argument specification to the method.
 */
- (void) addArgument: (DKArgument*)arg
           direction: (NSString*)direction;

/**
 * Deserializes the appropriate values from the message iterator and places them
 * in the invocation. Use type to indicate whether this is done for an method
 * call or method return and doBox to indicate whether the values should or
 * should not be boxed.
 */
- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
   	            messageType: (int)type
	                 boxing: (BOOL)doBox;
/**
 * Serializes the appropriate values from the invocation and appends them using
 * the message iterator. Use type to indicate whether this is done for an method
 * call or method return and doBox to indicate whether the values should or
 * should not be boxed.
 */
- (void)marshallFromInvocation: (NSInvocation*)inv
                  intoIterator: (DBusMessageIter*)iter
                   messageType: (int)type
                        boxing: (BOOL)doBox;
@end

/**
 * _DKMethodIntrospect is a prototype for the D-Bus introspection method. It
 * will be added to the dispatch table of a proxy because we need it to dispatch
 * the initial introspection data.
 */
extern DKMethod *_DKMethodIntrospect;
