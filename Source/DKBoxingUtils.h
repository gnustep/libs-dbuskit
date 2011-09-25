/** Declarations of helper functions for boxing and unboxing D-Bus types.
   Copyright (C) 2011 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: September 2011

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

#import <Foundation/NSObject.h>

/**
 * Returns the builtin default class for boxing the named D-Bus type.
 */
Class
DKBuiltinObjCClassForDBusType(int type);


/**
 * Convert from Objective-C types to D-Bus types. NOTE: This is not meant to
 * be complete. It is just used to give some hints for the boxing of D-Bus
 * variant types. (NSValue responds to -objCType, so we can use the information
 * to construct a correctly typed DKArgument at least some of the time.)
 */
int
DKDBusTypeForObjCType(const char* code);

/**
 * Convert D-Bus types to corresponding Objective-C types. Assumes that complex
 * types are always boxed.
 */
const char*
DKUnboxedObjCTypeForDBusType(int type);


/**
 * Returns the size of a primitive Objective-C type.
 */
size_t
DKPrimitiveObjCTypeSize(const char* code);

/**
 * Returns whether the D-Bus type is an integer type.
 */
BOOL
DKDBusTypeIsIntegerType(int type);

/**
 * Returns whether the Objective-C type is an integer type.
 */
BOOL
DKObjCTypeIsIntegerType(const char* code);

/**
 * Returns whether the D-Bus integer type is unsigned.
 */
BOOL
DKDBusTypeIsUnsigned(int type);

/**
 * Returns whether the Objective-C integer type is unsigned.
 */
BOOL
DKObjCTypeIsUnsigned(const char* code);

/**
 * Returns whether the D-Bus type is a floating point type.
 */
BOOL
DKDBusTypeIsFPType(int type);

/**
 * Returns whether the Objective-C type is a floating point type.
 */
BOOL
DKObjCTypeIsFPType(const char* code);

/**
 * Returns the size of the Objective-C type corresponding to the D-Bus type.
 */
size_t
DKUnboxedObjCTypeSizeForDBusType(int type);

/**
 * Returns whether a value of the given D-Bus type can fit into the space of the Objective-C type code.
 */
BOOL
DKDBusTypeFitsIntoObjCType(int type, const char* code);

/**
 * Returns whether a value of the given Objective-C type can fit into the space of the D-Bus type.
 */
BOOL
DKObjCTypeFitsIntoDBusType(const char* code, int type);

/**
 * Returns whether a value of the given Objective-C type can fit into the space of another ObjC type.
 */
BOOL
DKObjCTypeFitsIntoObjCType(const char* code, const char* otherCode);
