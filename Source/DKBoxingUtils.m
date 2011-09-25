/** Helper functions for boxing and unboxing D-Bus types.
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

#import "DKBoxingUtils.h"
#import "DKArgument.h"

#import "config.h"

#import <Foundation/NSValue.h>
#import <Foundation/NSFileHandle.h>

#include <dbus/dbus.h>

Class
DKBuiltinObjCClassForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
    case DBUS_TYPE_DOUBLE:
      return [NSNumber class];
    case DBUS_TYPE_STRING:
      return [NSString class];
    case DBUS_TYPE_OBJECT_PATH:
      return [DKProxy class];
    case DBUS_TYPE_SIGNATURE:
      return [DKArgument class];
    // Some DBUS_TYPE_ARRAYs will actually be dictionaries if they contain
    // DBUS_TYPE_DICT_ENTRies.
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
      return [NSArray class];
#ifdef  DBUS_TYPE_UNIX_FD
    case DBUS_TYPE_UNIX_FD:
      return [NSFileHandle class];
#endif
    // The following types have no explicit representation, they will either not
    // be handled at all, or their boxing is determined by the container resp.
    // the contained type.
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_VARIANT:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      break;
  }
  return Nil;
}


int
DKDBusTypeForObjCType(const char* code)
{
  switch (*code)
  {
    case _C_BOOL:
      return DBUS_TYPE_BOOLEAN;
    case _C_CHR:
    case _C_SHT:
      return DBUS_TYPE_INT16;
    case _C_INT:
      return DBUS_TYPE_INT32;
    case _C_LNG_LNG:
      return DBUS_TYPE_INT64;
    case _C_UCHR:
      return DBUS_TYPE_BYTE;
    case _C_USHT:
      return DBUS_TYPE_UINT16;
    case _C_UINT:
      return DBUS_TYPE_UINT32;
    case _C_ULNG_LNG:
      return DBUS_TYPE_UINT64;
    case _C_FLT:
    case _C_DBL:
      return DBUS_TYPE_DOUBLE;
    case _C_CHARPTR:
      return DBUS_TYPE_STRING;
    case _C_ID:
      return DBUS_TYPE_OBJECT_PATH;
    case _C_ARY_B:
      return DBUS_TYPE_ARRAY;
    case _C_STRUCT_B:
      return DBUS_TYPE_STRUCT;
    default:
      return DBUS_TYPE_INVALID;
  }
  return DBUS_TYPE_INVALID;
}

const char*
DKUnboxedObjCTypeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return @encode(unsigned char);
    case DBUS_TYPE_BOOLEAN:
      return @encode(BOOL);
    case DBUS_TYPE_INT16:
      return @encode(int16_t);
    case DBUS_TYPE_UINT16:
      return @encode(uint16_t);
    case DBUS_TYPE_INT32:
      return @encode(int32_t);
    case DBUS_TYPE_UINT32:
      return @encode(uint32_t);
    case DBUS_TYPE_INT64:
      return @encode(int64_t);
    case DBUS_TYPE_UINT64:
      return @encode(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return @encode(double);
    case DBUS_TYPE_STRING:
      return @encode(char*);
#   ifdef DBUS_TYPE_UNIX_FD
    // Qua POSIX, file descriptors are integer sized.
    case DBUS_TYPE_UNIX_FD:
      return @encode(int);
#   endif
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return @encode(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return '\0';
  }
  return '\0';
}

size_t
DKUnboxedObjCTypeSizeForDBusType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
      return sizeof(char);
    case DBUS_TYPE_BOOLEAN:
      return sizeof(BOOL);
    case DBUS_TYPE_INT16:
      return sizeof(int16_t);
    case DBUS_TYPE_UINT16:
      return sizeof(uint16_t);
    case DBUS_TYPE_INT32:
      return sizeof(int32_t);
    case DBUS_TYPE_UINT32:
      return sizeof(uint32_t);
    case DBUS_TYPE_INT64:
      return sizeof(int64_t);
    case DBUS_TYPE_UINT64:
      return sizeof(uint64_t);
    case DBUS_TYPE_DOUBLE:
      return sizeof(double);
    case DBUS_TYPE_STRING:
      return sizeof(char*);
#   ifdef DBUS_TYPE_UNIX_FD
    case DBUS_TYPE_UNIX_FD:
      return sizeof(int);
#   endif
    // We always box the following types:
    case DBUS_TYPE_OBJECT_PATH:
    case DBUS_TYPE_ARRAY:
    case DBUS_TYPE_STRUCT:
    case DBUS_TYPE_VARIANT:
      return sizeof(id);
    // And because we do, the following types will never appear in a signature:
    case DBUS_TYPE_INVALID:
    case DBUS_TYPE_SIGNATURE:
    case DBUS_TYPE_DICT_ENTRY:
    default:
      return 0;
  }
  return 0;
}

size_t
DKPrimitiveObjCTypeSize(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return 0;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return 0;
  }

  switch (*code)
  {
#   define APPLY_TYPE(typeName, name, capitalizedName, encodingChar) \
    case encodingChar: \
      return sizeof(typeName);
#   define NON_INTEGER_TYPES 1
#   include "type_encoding_cases.h"
    default:
      return 0;
  }
}

BOOL
DKDBusTypeIsIntegerType(int type)
{
  switch (type)
  {
    case DBUS_TYPE_BYTE:
    case DBUS_TYPE_BOOLEAN:
    case DBUS_TYPE_INT16:
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_INT32:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_INT64:
    case DBUS_TYPE_UINT64:
      return YES;
    default:
      return NO;
  }
  return NO;
}


BOOL
DKObjCTypeIsIntegerType(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'c':
    case 's':
    case 'i':
    case 'l':
    case 'q':
    case 'C':
    case 'B':
    case 'S':
    case 'I':
    case 'L':
    case 'Q':
      return YES;
    default:
      return NO;
  }
  return NO;
}

BOOL
DKDBusTypeIsUnsigned(int type)
{
  switch (type)
  {
    case DBUS_TYPE_UINT16:
    case DBUS_TYPE_UINT32:
    case DBUS_TYPE_UINT64:
      return YES;
    default:
      return NO;
  }
}

BOOL
DKObjCTypeIsUnsigned(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'C':
    case 'S':
    case 'I':
    case 'L':
    case 'Q':
      return YES;
    default:
      return NO;
  }
  return NO;
}


BOOL
DKDBusTypeIsFPType(int type)
{
  return (DBUS_TYPE_DOUBLE == type);
}

BOOL
DKObjCTypeIsFPType(const char* code)
{
  // Guard against NULL pointers
  if (NULL == code)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *code)
  {
    return NO;
  }

  switch (*code)
  {
    case 'd':
    case 'f':
      return YES;
    default:
      return NO;
  }
  return NO;
}

static inline BOOL
_DKObjCTypeFitsIntoObjCType(const char *sourceType, const char *targetType)
{
  // NOTE This function is only ever called from functions that already did
  // sanity checks on the arguments.
  BOOL sourceIsInteger = NO;
  BOOL targetIsInteger = NO;
  BOOL sourceIsFP = NO;
  BOOL targetIsFP = NO;
  BOOL sourceIsUnsigned = NO;
  BOOL targetIsUnsigned = NO;
  size_t sourceSize = 0;
  size_t targetSize = 0;


  // First test: Conversion between equal types always works.
  if (*sourceType == *targetType)
  {
    return YES;
  }

  /*
   * More complex cases. We need to gather information about the types. Of that,
   * we will always need the size.
   */
  sourceSize = DKPrimitiveObjCTypeSize(sourceType);
  targetSize = DKPrimitiveObjCTypeSize(targetType);
  sourceIsInteger = DKObjCTypeIsIntegerType(sourceType);
  targetIsInteger = DKObjCTypeIsIntegerType(targetType);

  if (sourceIsInteger && targetIsInteger)
  {
    /*
     * Both types are integers. Find out whether they are signed.
     */

    sourceIsUnsigned = DKObjCTypeIsUnsigned(sourceType);
    targetIsUnsigned = DKObjCTypeIsUnsigned(targetType);
    if (targetSize > sourceSize)
    {
      /*
       * If the type we are converting to needs more storage space than the
       * source, we're save, even if we are converting from an unsigned to a
       * signed value. But we don't claim that we can convert a signed value
       * to an unsigned.
       * FIXME: Of course we could try to examine the concrete value in every
       * case and only fail when it actually doesn't fit.
       */
      if ((sourceIsUnsigned == targetIsUnsigned)
	|| (sourceIsUnsigned && (NO == targetIsUnsigned)))
      {
	return YES;
      }
    }

    /* If both types are of equal size, we also require equal signedness. */
    if ((targetSize == sourceSize) && (sourceIsUnsigned == targetIsUnsigned))
    {
      return YES;
    }
  }

  sourceIsFP = DKObjCTypeIsFPType(sourceType);
  targetIsFP = DKObjCTypeIsFPType(targetType);

  if (sourceIsFP && targetIsFP)
  {
    /* This is easier if only floating point values are involved. */
    if (targetSize >= sourceSize)
    {
      return YES;
    }
  }
  return NO;
}

BOOL
DKDBusTypeFitsIntoObjCType(int origType, const char* objCType)
{
  const char* convertedDBusType;
  // Guard against NULL pointers
  if (NULL == objCType)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *objCType)
  {
    return NO;
  }

  if (DBUS_TYPE_INVALID == origType)
  {
    return NO;
  }
  convertedDBusType = DKUnboxedObjCTypeForDBusType(origType);

  if (convertedDBusType == NULL)
  {
    return NO;
  }
  if (*convertedDBusType == '\0')
  {
    return NO;
  }
  return _DKObjCTypeFitsIntoObjCType(convertedDBusType, objCType);
}

BOOL
DKObjCTypeFitsIntoDBusType(const char *origType, int DBusType)
{
  const char* convertedDBusType;
  // Guard against NULL pointers
  if (NULL == origType)
  {
    return NO;
  }

  // Guard against empty strings
  if ('\0' == *origType)
  {
    return NO;
  }

  if (DBUS_TYPE_INVALID == DBusType)
  {
    return NO;
  }
  convertedDBusType = DKUnboxedObjCTypeForDBusType(DBusType);

  if (convertedDBusType == NULL)
  {
    return NO;
  }
  if (*convertedDBusType == '\0')
  {
    return NO;
  }
  return _DKObjCTypeFitsIntoObjCType(origType, convertedDBusType);
}

BOOL
DKObjCTypeFitsIntoObjCType(const char *sourceType, const char *targetType)
{
  // Guard against NULL pointers
  if ((NULL == sourceType) || (NULL == targetType))
  {
    return NO;
  }

  // Guard against empty strings
  if (('\0' == *sourceType) || ('\0' == *targetType))
  {
    return NO;
  }

  return _DKObjCTypeFitsIntoObjCType(sourceType, targetType);
}
