/** Implementation of DKArgument class for boxing and unboxing D-Bus types.
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

   <title>DKArgument class reference</title>
   */

#import <Foundation/NSArray.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSHashTable.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSNull.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>

#import "DBusKit/DKProxy.h"
#import "DKEndpoint.h"
#import "DKOutgoingProxy.h"
#import "DKArgument.h"

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#include <dbus/dbus.h>

NSString *DKArgumentDirectionIn = @"in";
NSString *DKArgumentDirectionOut = @"out";


/*
 * Macros to call D-Bus function and check whether they returned OOM:
 */

#define DK_MARSHALLING_RAISE_OOM [NSException raise: @"DKArgumentMarshallingException"\
                                             format: @"Out of memory when marshalling arument."]

#define DK_ITER_APPEND(iter, type, addr) do {\
  if (NO == (BOOL)dbus_message_iter_append_basic(iter, type, (void*)addr))\
  {\
    DK_MARSHALLING_RAISE_OOM; \
  }\
}  while (0)

#define DK_ITER_OPEN_CONTAINER(iter, type, sig, subIter) do {\
  if (NO == (BOOL)dbus_message_iter_open_container(iter, type, sig, subIter))\
  {\
    DK_MARSHALLING_RAISE_OOM; \
  }\
} while (0)

#define DK_ITER_CLOSE_CONTAINER(iter, subIter) do {\
  if (NO == (BOOL)dbus_message_iter_close_container(iter, subIter))\
  {\
    DK_MARSHALLING_RAISE_OOM; \
  }\
} while (0)

static Class
DKObjCClassForDBusType(int type)
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

/*
 * Conversion from Objective-C types to D-Bus types. NOTE: This is not meant to
 * be complete. It is just used to give some hints for the boxing of D-Bus
 * variant types. (NSValue responds to -objCType, so we can use the information
 * to construct a correctly typed DKArgument at least some of the time.)
 */
static int
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

/*
 * Map D-Bus types to corresponding Objective-C types. Assumes that complex
 * types are always boxed.
 */
static char*
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
static size_t
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

/*
 * Expose DKProxy privates that we need to access.
 */
@interface DKProxy (Private)
- (NSString*)_path;
- (NSString*)_service;
- (DKEndpoint*)_endpoint;
- (BOOL)_isLocal;
@end


/*
 * Private Container argument subclasses:
 */

@interface DKStructTypeArgument: DKContainerTypeArgument
@end

@interface DKArrayTypeArgument: DKContainerTypeArgument
- (BOOL) isDictionary;
- (void) setIsDictionary: (BOOL)isDict;
@end

/* D-Bus marshalls dictionaries as arrays of key/value pairs. */
@interface DKDictionaryTypeArgument: DKArrayTypeArgument
@end

@interface DKVariantTypeArgument: DKContainerTypeArgument
- (DKArgument*) DKArgumentWithObject: (id)object;
@end

/* It seems sensible to regard dict entries as struct types. */
@interface DKDictEntryTypeArgument: DKStructTypeArgument
- (DKArgument*) keyArgument;
- (DKArgument*) valueArgument;
- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                          value: (id*)value
                            key: (id*)key;
- (void) marshallObject: (id)object
                 forKey: (id)key
           intoIterator: (DBusMessageIter*)iter;
@end


/*
 * Tables and paraphernalia for managing unboxing of objects: We want some
 * degree of flexibility on how to unbox objects of arbitrary types. To that
 * end, we define two tables:
 *
 * (1) selectorTypeMap, which maps selectors used to unbox objects to D-Bus
 *     types so that we can construct appropriate DKArguments if we encounter
 *     objects responding to the selector.
 *
 * (2) typeSelectorMap, which maps D-Bus types to hash-tables containing all
 *     selectors that can be used to obtain an unboxed value of a specified
 *     type.
 *
 * NOTE: Unfortunately, we cannot unbox container types this way.
 */
static NSMapTable *selectorTypeMap;
static NSMapTable *typeSelectorMap;
static NSLock *selectorTypeMapLock;


typedef struct
{
  SEL selector;
  int type;
} DKSelectorTypePair;


#define DK_INSTALL_TYPE_SELECTOR_PAIR(type,theSel) \
 do \
  {\
    SEL selector = theSel;\
    NSHashTable *selTable = NSCreateHashTable(NSIntHashCallBacks,\
     1); \
    NSMapInsert(selectorTypeMap,\
      (void*)(uintptr_t)selector,\
      (void*)(intptr_t)type);\
    NSMapInsert(typeSelectorMap,\
      (void*)(intptr_t)type,\
      (void*)selTable);\
    NSHashInsert(selTable,selector);\
  } while (0)


static void
DKInstallDefaultSelectorTypeMapping()
{
  [selectorTypeMapLock lock];
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_STRING, @selector(UTF8String));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_INT64, @selector(longLongValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_UINT64, @selector(unsignedLongLongValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_INT32, @selector(intValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_UINT32, @selector(unsignedIntValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_INT16, @selector(shortValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_UINT16, @selector(unsignedShortValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_BYTE, @selector(unsignedCharValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_BOOLEAN, @selector(boolValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_DOUBLE, @selector(doubleValue));
  DK_INSTALL_TYPE_SELECTOR_PAIR(DBUS_TYPE_DOUBLE, @selector(floatValue));
  [selectorTypeMapLock unlock];
}

static void
DKRegisterSelectorTypePair(DKSelectorTypePair *pair)
{
  NSHashTable *selTable = nil;
  SEL selector = pair->selector;
  int type = pair->type;
  void* mapReturn = NULL;
  if (0 == selector)
  {
    return;
  }


  [selectorTypeMapLock lock];
  selTable = NSMapGet(typeSelectorMap, (void*)(intptr_t)type);

  if (!selTable)
  {
    [selectorTypeMapLock unlock];
    return;
  }

  mapReturn = NSMapInsertIfAbsent(selectorTypeMap,
    (void*)(uintptr_t)selector,
    (void*)(intptr_t)type);

  // InsertIfAbsent returns NULL if the key had been absent, which is the only
  // case where we also want to install the new type-selector mapping.
  if (NULL == mapReturn)
  {
    NSHashInsertIfAbsent(selTable, (void*)(uintptr_t)selector);
  }
  [selectorTypeMapLock unlock];
}


static SEL
DKSelectorForUnboxingObjectAsType(id object, int DBusType)
{
  SEL theSel = 0;
  NSHashTable *table = nil;
  NSHashEnumerator tableEnum;
  [selectorTypeMapLock lock];
  table = NSMapGet(typeSelectorMap, (void*)(intptr_t)DBusType);
  tableEnum = NSEnumerateHashTable(table);
  while (0 != (theSel = (SEL)NSNextHashEnumeratorItem(&tableEnum)))
  {
    if ([object respondsToSelector: theSel])
    {
      NSEndHashTableEnumeration(&tableEnum);
      [selectorTypeMapLock unlock];
      return theSel;
    }
  }
  NSEndHashTableEnumeration(&tableEnum);
  [selectorTypeMapLock unlock];
  return 0;
}

static int
DKDBusTypeForUnboxingObject(id object)
{
  int type = DBUS_TYPE_INVALID;
  // Fast case: The object implements objCType, so we can simply gather the
  // D-Bus type from the Obj-C type code.
  if ([object respondsToSelector: @selector(objCType)])
  {
    type = DKDBusTypeForObjCType([object objCType]);
  }

  /*
   * Special case: NSString. It responds to all kinds of crazy selectors,
   * converting the string to a numeric value.  So we default to returning the
   * string type for NSString.
   */
  if ([object isKindOfClass: [NSString class]])
  {
    return DBUS_TYPE_STRING;
  }

  // Slow case: We need to find a selector in the table and get the matching
  // type.
  if (DBUS_TYPE_INVALID == type)
  {
    SEL aSel = 0;
    NSMapEnumerator mapEnum;
    [selectorTypeMapLock lock];
    mapEnum = NSEnumerateMapTable(selectorTypeMap);
    while (NSNextMapEnumeratorPair(&mapEnum,
      (void**)&aSel,
      (void**)&type))
    {
      if (aSel != 0)
      {
	if ([object respondsToSelector: aSel])
	{
	  // The object responds to the selector. We need to make sure that we
	  // get a correctly sized return value by invoking the corresponding
	  // method.
	  NSMethodSignature *sig = [object methodSignatureForSelector: aSel];
	  if ((type == DKDBusTypeForObjCType([sig methodReturnType])))
	  {
	    NSEndMapTableEnumeration(&mapEnum);
	    [selectorTypeMapLock unlock];
	    return type;
	  }
	}
      }
    }
    NSEndMapTableEnumeration(&mapEnum);
    [selectorTypeMapLock unlock];
  }
  return type;
}

/**
 *  DKArgument encapsulates D-Bus argument information
 */
@implementation DKArgument
+ (void) initialize
{
  if ([DKArgument class] != self)
  {
    return;
  }

  selectorTypeMap = NSCreateMapTable(NSIntMapKeyCallBacks,
    NSIntMapValueCallBacks,
    17); // We have 17 D-Bus types.
  typeSelectorMap = NSCreateMapTable(NSIntMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    17); // We have 17 D-Bus types.


  selectorTypeMapLock = [NSLock new];
  DKInstallDefaultSelectorTypeMapping();


}

+ (void)registerUnboxingSelector: (SEL)selector
                     forDBusType: (int)type
{

  DKSelectorTypePair pair = {selector, type};
  DKRegisterSelectorTypePair(&pair);
}

- (id) initWithIterator: (DBusSignatureIter*)iterator
                   name: (NSString*)_name
                 parent: (id)_parent
{
  if (nil == (self = [super initWithName: _name
                                  parent: _parent]))
  {
    return nil;
  }

  DBusType = dbus_signature_iter_get_current_type(iterator);

  if ((dbus_type_is_container(DBusType))
    && (![self isKindOfClass: [DKContainerTypeArgument class]]))
  {
    NSDebugMLog(@"Incorrectly initalized a non-container argument with a container type, reinitializing as container type.");
    [self release];
    return [[DKContainerTypeArgument alloc] initWithIterator: iterator
                                                        name: _name
                                                      parent: _parent];
  }
  objCEquivalent = DKObjCClassForDBusType(DBusType);
  return self;
}

- (id)initWithDBusSignature: (const char*)DBusTypeString
                       name: (NSString*)_name
                     parent: (id)_parent
{
  DBusSignatureIter myIter;
  if (!dbus_signature_validate_single(DBusTypeString, NULL))
  {
    NSWarnMLog(@"Not a single D-Bus type signature ('%s'), ignoring argument", DBusTypeString);
    [self release];
    return nil;
  }

  dbus_signature_iter_init(&myIter, DBusTypeString);
  return [self initWithIterator: &myIter
                           name: _name
                         parent: _parent];
}



- (void)setObjCEquivalent: (Class)class
{
  objCEquivalent = class;
}

- (Class) objCEquivalent
{
  return objCEquivalent;
}

- (int) DBusType
{
  return DBusType;
}

- (NSString*) DBusTypeSignature
{
  return [NSString stringWithCharacters: (unichar*)&DBusType length: 1];

}

- (char*) unboxedObjCTypeChar
{
  return DKUnboxedObjCTypeForDBusType(DBusType);
}

- (size_t)unboxedObjCTypeSize
{
  return DKUnboxedObjCTypeSizeForDBusType(DBusType);
}
- (BOOL) isContainerType
{
  return NO;
}




- (BOOL) unboxValue: (id)value
         intoBuffer: (long long*)buffer
{
  SEL aSelector = 0;
  switch (DBusType)
  {
    case DBUS_TYPE_BYTE:
       if (([value respondsToSelector: @selector(unsignedCharValue)])
         || (nil == value))
       {
	 *buffer = [value unsignedCharValue];
         return YES;
       }
       break;
    case DBUS_TYPE_BOOLEAN:
       if (([value respondsToSelector: @selector(boolValue)])
         || (nil == value))
       {
	 *buffer = [value boolValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT16:
       if (([value respondsToSelector: @selector(shortValue)])
         || (nil == value))
       {
	 *buffer = [value shortValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT32:
       if (([value respondsToSelector: @selector(intValue)])
         || (nil == value))
       {
	 *buffer = [value intValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT16:
       if (([value respondsToSelector: @selector(unsignedShortValue)])
         || (nil == value))
       {
	 *buffer = [value unsignedShortValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT32:
       if (([value respondsToSelector: @selector(unsignedIntValue)])
         || (nil == value))
       {
	 *buffer = [value unsignedIntValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_INT64:
       if (([value respondsToSelector: @selector(longLongValue)])
         || (nil == value))
       {
	 *buffer = [value longLongValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_UINT64:
       if (([value respondsToSelector: @selector(unsignedLongLongValue)])
         || (nil == value))
       {
	 *buffer = [value unsignedLongLongValue];
	 return YES;
       }
       break;
    case DBUS_TYPE_DOUBLE:
       if (([value respondsToSelector: @selector(doubleValue)])
         || (nil == value))
       {
	 union fpAndLLRep
	 {
           long long buf;
	   double val;
	 } rep;
	 rep.val = [value doubleValue];
	 *buffer = rep.buf;
	 return YES;
       }
       break;
    case DBUS_TYPE_STRING:
      if ([value respondsToSelector: @selector(UTF8String)])
      {
        *buffer = (uintptr_t)(void*)[value UTF8String];
        return YES;
      }
      else if (nil == value)
      {
        *buffer = (uintptr_t)(void*)"";
        return YES;
      }
      break;
    case DBUS_TYPE_OBJECT_PATH:
      if ([value isKindOfClass: [DKProxy class]])
      {
        DKProxy *rootProxy = [self proxyParent];
        /*
         * Handle remote objects:
         * We need to make sure that the paths are from the same proxy, because
         * that is the widest scope in which they are valid.
         */
        if ([rootProxy hasSameScopeAs: value])
        {
          *buffer = (uintptr_t)[[value _path] UTF8String];
          return YES;
        }
      }
      else if (nil == value)
      {
        *buffer = (uintptr_t)(void*)"";
        return YES;
      }
      else
      {
        DKProxy *rootProxy = [self proxyParent];
        /*
         * Handle local objects:
         * We need to find out if the proxy we derive from is an outgoing proxy.
         * If so, we can export the object via D-Bus, so that the caller can
         * interact with it.
         */
         if ([rootProxy _isLocal])
         {
 	   DKOutgoingProxy *newProxy = [DKOutgoingProxy proxyWithParent: rootProxy
	                                                         object: value];
	   *buffer = (uintptr_t)[[newProxy _path] UTF8String];
	   return YES;
         }
      }
      break;
    case DBUS_TYPE_SIGNATURE:
      if ([value respondsToSelector: @selector(DBusTypeSignature)])
      {
	*buffer = (uintptr_t)(void*)[[value DBusTypeSignature] UTF8String];
	return YES;
      }
      else if (value == nil)
      {
        *buffer = (uintptr_t)(void*)"";
        return YES;
      }
      break;
    default:
      break;
  }

  /*
   * None of the built in mappings worked. We still have a slight chance that a
   * custom selector was installed to unbox the type. So we try again by looking
   * up the selector.
   */
   aSelector = DKSelectorForUnboxingObjectAsType(value, DBusType);
   if (0 != aSelector)
   {
     NSMethodSignature *sig = [value methodSignatureForSelector: aSelector];
     // Only call it if we don't need arguments and the returnvalue fits into
     // the buffer:
     if ((2 == [sig numberOfArguments])
       && ([sig methodReturnLength] <= sizeof(long long)))
     {
       IMP unboxFun = [value methodForSelector: aSelector];

       // Cast to void* first so that we don't get any funny implicit casts
       *buffer = (long long)(void*)unboxFun(value, aSelector);
       return YES;
     }
   }

  return NO;
}

- (id) boxedValueForValueAt: (void*)buffer
{
  switch (DBusType)
  {
    case DBUS_TYPE_BYTE:
      return [objCEquivalent numberWithUnsignedChar: *(unsigned char*)buffer];
    case DBUS_TYPE_BOOLEAN:
      return [objCEquivalent numberWithBool: *(BOOL*)buffer];
    case DBUS_TYPE_INT16:
      return [objCEquivalent numberWithShort: *(int16_t*)buffer];
    case DBUS_TYPE_UINT16:
      return [objCEquivalent numberWithUnsignedShort: *(uint16_t*)buffer];
    case DBUS_TYPE_INT32:
      return [objCEquivalent numberWithInt: *(int32_t*)buffer];
    case DBUS_TYPE_UINT32:
      return [objCEquivalent numberWithUnsignedInt: *(uint32_t*)buffer];
    case DBUS_TYPE_INT64:
      return [objCEquivalent numberWithLongLong: *(int64_t*)buffer];
    case DBUS_TYPE_UINT64:
      return [objCEquivalent numberWithUnsignedLongLong: *(uint64_t*)buffer];
    case DBUS_TYPE_DOUBLE:
      return [objCEquivalent numberWithDouble: *(double*)buffer];
    case DBUS_TYPE_STRING:
      return [objCEquivalent stringWithUTF8String: *(char**)buffer];
    case DBUS_TYPE_OBJECT_PATH:
    {
      /*
       * To handle object-paths, we follow the argument/method tree back to the
       * proxy where it was created and create a new proxy with the proper
       * settings.
       */
      DKProxy *ancestor = [self proxyParent];
      NSString *service = [ancestor _service];
      DKEndpoint *endpoint = [ancestor _endpoint];
      NSString *path = [[NSString alloc] initWithUTF8String: *(char**)buffer];
      DKProxy *newProxy = [objCEquivalent proxyWithEndpoint: endpoint
	                                         andService: service
	                                            andPath: path];
      [path release];
      return newProxy;
    }
    case DBUS_TYPE_SIGNATURE:
      return [[[objCEquivalent alloc] initWithDBusSignature: *(char**)buffer
                                                       name: nil
                                                     parent: nil] autorelease];
    default:
      return nil;
  }
  return nil;
}


- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
		        atIndex: (NSInteger)index
			 boxing: (BOOL)doBox
{
  // All basic types are guaranteed to fit into 64bit.
  uint64_t buffer = 0;

  // Type checking:
  const char *invType;
  const char *expectedType;

  // Check that the method contains the expected type.
  NSAssert((dbus_message_iter_get_arg_type(iter) == DBusType),
    @"Type mismatch between D-Bus message and introspection data.");

  if (doBox)
  {
    expectedType = @encode(id);
  }
  else
  {
    expectedType = [self unboxedObjCTypeChar];
  }

  if (index == -1)
  {
    invType = [[inv methodSignature] methodReturnType];
  }
  else
  {
    invType = [[inv methodSignature] getArgumentTypeAtIndex: index];
  }

  // Check whether the invocation has a matching call frame:
  NSAssert((0 == strcmp(invType, expectedType)),
    @"Type mismatch between introspection data and invocation.");

  dbus_message_iter_get_basic(iter, (void*)&buffer);

  if (doBox)
  {
    id value = [self boxedValueForValueAt: (void*)&buffer];
    if (index == -1)
    {
      [inv setReturnValue: &value];
    }
    else
    {
      [inv setArgument: &value
               atIndex: index];
    }
  }
  else
  {
    if (index == -1)
    {
      [inv setReturnValue: (void*)&buffer];
    }
    else
    {
      [inv setArgument: (void*)&buffer
               atIndex: index];
    }
  }
}

-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  // All basic types are guaranteed to fit into 64bit.
  uint64_t buffer = 0;

  // Check that the method contains the expected type.
  NSAssert((dbus_message_iter_get_arg_type(iter) == DBusType),
    @"Type mismatch between D-Bus message and introspection data.");

  dbus_message_iter_get_basic(iter, (void*)&buffer);

  return [self boxedValueForValueAt: (void*)&buffer];
}

- (void) marshallArgumentAtIndex: (NSInteger)index
                  fromInvocation: (NSInvocation*)inv
                    intoIterator: (DBusMessageIter*)iter
                          boxing: (BOOL)doBox
{
  uint64_t buffer = 0;
  const char* invType;
  const char* expectedType;

  if (doBox)
  {
    expectedType = @encode(id);
  }
  else
  {
    expectedType = [self unboxedObjCTypeChar];
  }

  if (-1 == index)
  {
    invType = [[inv methodSignature] methodReturnType];
  }
  else
  {
    invType = [[inv methodSignature] getArgumentTypeAtIndex: index];
  }

  NSAssert((0 == strcmp(expectedType, invType)),
    @"Type mismatch between introspection data and invocation.");

  if (doBox)
  {
    id value = nil;

    if (-1 == index)
    {
      [inv getReturnValue: &value];
    }
    else
    {
      [inv getArgument: &value
               atIndex: index];
    }

    if (NO == [self unboxValue: value intoBuffer: (long long*)(void*)&buffer])
    {
      [NSException raise: @"DKArgumentUnboxingException"
                  format: @"Could not unbox object '%@' into D-Bus format",
        value];
    }
  }
  else
  {
    if (-1 == index)
    {
      [inv getReturnValue: (void*)&buffer];
    }
    else
    {
      [inv getArgument: (void*)&buffer
               atIndex: index];
    }
  }

  DK_ITER_APPEND(iter, DBusType, &buffer);
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  long long int buffer = 0;
  if (NO == [self unboxValue: object intoBuffer: &buffer])
  {
    [NSException raise: @"DKArgumentUnboxingException"
                format: @"Could not unbox object '%@' into D-Bus format",
      object];
  }
  DK_ITER_APPEND(iter, DBusType, &buffer);
}

@end


@implementation DKContainerTypeArgument

- (id)initWithIterator: (DBusSignatureIter*)iterator
                  name: (NSString*)_name
                parent: (id)_parent
{
  DBusSignatureIter subIterator;
  Class concreteClass = Nil;

  // Get the type from the iterator:
  DBusType = dbus_signature_iter_get_current_type(iterator);
  if (!dbus_type_is_container(DBusType))
  {
    NSWarnMLog(@"Incorrectly initialized container type D-Bus argument ('%@' is not a container type).",
      [NSString stringWithCharacters: (unichar*)&DBusType length: 1]);
      [self release];
      return nil;
  }


  /*
   * If the initializer is called for the DKContainerTypeArgument class, we need
   * to get concrete subclass from the DBusType
   */
  if ([DKContainerTypeArgument class] == [self class])
  {
    switch (DBusType)
    {
      case DBUS_TYPE_VARIANT:
        concreteClass = [DKVariantTypeArgument class];
        break;
      case DBUS_TYPE_ARRAY:
        concreteClass = [DKArrayTypeArgument class];
        break;
      case DBUS_TYPE_STRUCT:
        concreteClass = [DKStructTypeArgument class];
        break;
      case DBUS_TYPE_DICT_ENTRY:
        concreteClass = [DKDictEntryTypeArgument class];
        break;
      default:
        NSWarnMLog(@"Cannot handle unkown container type.");
        [self release];
        return nil;
    }

    [self release];
    return [[concreteClass alloc] initWithIterator: iterator
                                              name: _name
                                            parent: _parent];
  }

  if (nil == (self = [super initWithIterator: iterator
                                        name: _name
                                      parent: _parent]))
  {
    return nil;
  }


  children = [[NSMutableArray alloc] init];

  /*
   * A shortcut is needed for variant types. libdbus classifies them as
   * containers, but it is clearly wrong about that at least with regard to
   * the signatures:
   * They have no children and dbus will fail and crash if it tries to loop
   * over their non-existent sub-arguments. Hence we return after setting the
   * subclass.
   */

  if (DBUS_TYPE_VARIANT == DBusType)
  {
    return self;
  }

  /*
   * Create an iterator for the immediate subarguments of this argument and loop
   * over it until we have all the constituent types.
   */
  dbus_signature_iter_recurse(iterator, &subIterator);
  do
  {
    Class childClass = Nil;
    DKArgument *subArgument = nil;
    int subType = dbus_signature_iter_get_current_type(&subIterator);

    if (dbus_type_is_container(subType))
    {
       childClass = [DKContainerTypeArgument class];
    }
    else
    {
      childClass = [DKArgument class];
    }

    subArgument = [[childClass alloc] initWithIterator: &subIterator
                                                  name: _name
                                                parent: self];
    if (subArgument)
    {
      [children addObject: subArgument];
      [subArgument release];
    }
  } while (dbus_signature_iter_next(&subIterator));

  /* Be smart: If we are ourselves of DBUS_TYPE_DICT_ENTRY, then a
   * DBUS_TYPE_ARRAY argument above us is actually a dictionary, so we set the
   * type accordingly.
   */
  if (DBUS_TYPE_DICT_ENTRY == DBusType)
  {
    if ([parent isKindOfClass: [DKArrayTypeArgument class]])
    {
      if (DBUS_TYPE_ARRAY == [(id)parent DBusType])
      {
	[(id)parent setIsDictionary: YES];
      }
    }
  }
  return self;
}

/*
 * All container types are boxed.
 */
- (char*) unboxedObjCTypeChar
{
  return @encode(id);
}

- (size_t) unboxedObjCTypeSize
{
  return sizeof(id);
}

- (id) boxedValueForValueAt: (void*)buffer
{
  // It is a bad idea to try this on a container type.
  [self shouldNotImplement: _cmd];
  return nil;
}

- (NSString*) DBusTypeSignature
{
  NSMutableString *sig = [[NSMutableString alloc] init];
  NSString *ret = nil;
  // [[children fold] stringByAppendingString: @""]
  NSEnumerator *enumerator = [children objectEnumerator];
  DKArgument *subArg = nil;
  while (nil != (subArg = [enumerator nextObject]))
  {
    [sig appendString: [subArg DBusTypeSignature]];
  }

  switch (DBusType)
  {
    case DBUS_TYPE_VARIANT:
      [sig insertString: [NSString stringWithUTF8String: DBUS_TYPE_VARIANT_AS_STRING]
                atIndex: 0];
      break;
    case DBUS_TYPE_ARRAY:
      [sig insertString: [NSString stringWithUTF8String: DBUS_TYPE_ARRAY_AS_STRING]
                atIndex: 0];
      break;
    case DBUS_TYPE_STRUCT:
      [sig insertString: [NSString stringWithUTF8String: DBUS_STRUCT_BEGIN_CHAR_AS_STRING]
                                                atIndex: 0];
      [sig appendString: [NSString stringWithUTF8String: DBUS_STRUCT_END_CHAR_AS_STRING]];
      break;
    case DBUS_TYPE_DICT_ENTRY:
      [sig insertString: [NSString stringWithUTF8String: DBUS_DICT_ENTRY_BEGIN_CHAR_AS_STRING]
                                                atIndex: 0];
      [sig appendString: [NSString stringWithUTF8String: DBUS_DICT_ENTRY_END_CHAR_AS_STRING]];
      break;
    default:
      NSAssert(NO, @"Invalid D-Bus type when generating container type signature");
      break;
  }
  ret = [NSString stringWithString: sig];
  [sig release];
  return ret;
}

- (BOOL) isContainerType
{
  return YES;
}

- (NSArray*) children
{
  return children;
}

/*
 * Since we always box container types, we can simply set the argument/return
 * values to the object produced by unmarshalling.
 */
- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                 intoInvocation: (NSInvocation*)inv
		        atIndex: (NSInteger)index
			 boxing: (BOOL)doBox
{
  id value = [self unmarshalledObjectFromIterator: iter];

  if (-1 == index)
  {
    NSAssert((0 == strcmp(@encode(id), [[inv methodSignature] methodReturnType])),
      @"Type mismatch between introspection data and invocation.");
    [inv setReturnValue: &value];
  }
  else
  {
    NSAssert((0 == strcmp(@encode(id), [[inv methodSignature] getArgumentTypeAtIndex: index])),
      @"Type mismatch between introspection data and invocation.");
    [inv setArgument: &value
             atIndex: index];
  }
}

-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) marshallArgumentAtIndex: (NSInteger)index
                  fromInvocation: (NSInvocation*)inv
                    intoIterator: (DBusMessageIter*)iter
                          boxing: (BOOL)doBox
{
  id value = nil;

  if (-1 == index)
  {
    NSAssert((0 == strcmp(@encode(id), [[inv methodSignature] methodReturnType])),
      @"Type mismatch between introspection data and invocation.");
    [inv getReturnValue: &value];
  }
  else
  {
    NSAssert((0 == strcmp(@encode(id), [[inv methodSignature] getArgumentTypeAtIndex: index])),
      @"Type mismatch between introspection data and invocation.");
    [inv getArgument: &value
             atIndex: index];
  }
  [self marshallObject: value
          intoIterator: iter];
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  [self subclassResponsibility: _cmd];
}

- (void) dealloc
{
  [children release];
  [super dealloc];
}
@end;

@implementation DKArrayTypeArgument
- (id)initWithIterator: (DBusSignatureIter*)iterator
                  name: (NSString*)_name
                parent: (id)_parent
{
  NSUInteger childCount = 0;
  if (nil == (self = [super initWithIterator: iterator
                                        name: _name
                                      parent: _parent]))
  {
    return nil;
  }

  childCount = [children count];

  // Arrays can only have a single type:
  if (childCount != 1)
  {
    NSWarnMLog(@"Invalid number of children (%lu) for D-Bus array argument",
      childCount);
    [self release];
    return nil;
  }

  return self;
}

- (BOOL) isDictionary
{
  return NO;
}

- (void) setIsDictionary: (BOOL)isDict
{
# ifndef NDEBUG
  GSDebugAllocationRemove(isa, self);
# endif
  if (isDict)
  {
    object_setClass(self,[DKDictionaryTypeArgument class]);
    [self setObjCEquivalent: [NSDictionary class]];
  }
  else
  {
    // Not sure why somebody would want to do that
    object_setClass(self,[DKArrayTypeArgument class]);
    [self setObjCEquivalent: [NSArray class]];
  }
#ifndef NDEBUG
  GSDebugAllocationAdd(isa, self);
#endif
}

- (DKArgument*)elementTypeArgument
{
  return [children objectAtIndex: 0];
}


- (void) assertSaneIterator: (DBusMessageIter*)iter
{
  int childType = DBUS_TYPE_INVALID;
  // Make sure we are deserializing an array:
  NSAssert((DBUS_TYPE_ARRAY == dbus_message_iter_get_arg_type(iter)),
    @"Non array type when unmarshalling array from message.");
  childType = dbus_message_iter_get_element_type(iter);

  // Make sure we have the expected element type.
  NSAssert((childType == [[self elementTypeArgument] DBusType]),
    @"Type mismatch between D-Bus message and introspection data.");
}

-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  DKArgument *theChild = [self elementTypeArgument];
  DBusMessageIter subIter;
  NSMutableArray *theArray = [NSMutableArray new];
  NSArray *returnArray = nil;
  NSNull *theNull = [NSNull null];

  [self assertSaneIterator: iter];

  dbus_message_iter_recurse(iter, &subIter);
  do
  {
    id obj = [theChild unmarshalledObjectFromIterator: &subIter];
    if (nil == obj)
    {
      obj = theNull;
    }
    [theArray addObject: obj];
  } while (dbus_message_iter_next(&subIter));

  returnArray = [NSArray arrayWithArray: theArray];
  [theArray release];
  return returnArray;
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  DBusMessageIter subIter;
  DKArgument *theChild = [self elementTypeArgument];
  NSEnumerator *elementEnum = nil;
  id element = nil;
  if (nil == object)
  {
    object = [NSArray array];
  }
  NSAssert1([object respondsToSelector: @selector(objectEnumerator)],
    @"Cannot enumerate contents of %@ when creating D-Bus array.",
    object);

  DK_ITER_OPEN_CONTAINER(iter, DBUS_TYPE_ARRAY, [[theChild DBusTypeSignature] UTF8String], &subIter);

  elementEnum = [object objectEnumerator];
  NS_DURING
  {
    while (nil != (element = [elementEnum nextObject]))
    {
      [theChild marshallObject: element
                  intoIterator: &subIter];

    }
  }
  NS_HANDLER
  {
    // We are already screwed and don't care whether
    // dbus_message_iter_close_container() returns OOM.
    dbus_message_iter_close_container(iter, &subIter);
    [localException raise];
  }
  NS_ENDHANDLER

  DK_ITER_CLOSE_CONTAINER(iter, &subIter);
}
@end

@implementation DKDictionaryTypeArgument
/*
 * NOTE: Most of the time, this initializer will not be used, because we only
 * know ex-post whether something is a dictionary (by virtue of having elements
 * of DBUS_TYPE_DICT_ENTRY).
 */
- (id)initWithIterator: (DBusSignatureIter*)iterator
                  name: (NSString*)_name
                parent: (id)_parent
{
  if (nil == (self = [super initWithIterator: iterator
                                        name: _name
                                      parent: _parent]))
  {
    return nil;
  }

  if (![[self elementTypeArgument] isKindOfClass: [DKDictEntryTypeArgument class]])
  {
    NSWarnMLog(@"Invalid dictionary type argument (does not contan a dict entry).");
    [self release];
    return nil;
  }
  return self;
}

- (BOOL) isDictionary
{
  return YES;
}

- (void) assertSaneIterator: (DBusMessageIter*)iter
{
  [super assertSaneIterator: iter];
  NSAssert((DBUS_TYPE_DICT_ENTRY == dbus_message_iter_get_element_type(iter)),
    @"Non dict-entry type in iterator when unmarshalling a dictionary.");
}

-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  DKDictEntryTypeArgument *theChild = (DKDictEntryTypeArgument*)[self elementTypeArgument];
  DBusMessageIter subIter;
  NSMutableDictionary *theDictionary = [NSMutableDictionary new];
  NSDictionary *returnDictionary = nil;
  NSNull *theNull = [NSNull null];

  [self assertSaneIterator: iter];

  // We loop over the dict entries:
  dbus_message_iter_recurse(iter, &subIter);
  do
  {
    id value = nil;
    id key = nil;

    [theChild unmarshallFromIterator: &subIter
                               value: &value
                                 key: &key];
    if (key == nil)
    {
      key = theNull;
    }
    if (value == nil)
    {
      value = theNull;
    }

    if (nil == [theDictionary objectForKey: key])
    {
      /*
       * From the D-Bus specification:
       * "A message is considered corrupt if the same key occurs twice in the
       * same array of DICT_ENTRY. However, for performance reasons
       * implementations are not required to reject dicts with duplicate keys."
       * We choose to just ignore duplicate keys:
       */
      [theDictionary setObject: value
                        forKey: key];
    }
    else
    {
      NSWarnMLog(@"Ignoring duplicate key (%@) in D-Bus dictionary.", key);
    }

  } while (dbus_message_iter_next(&subIter));

  returnDictionary = [NSDictionary dictionaryWithDictionary: theDictionary];
  [theDictionary release];
  return returnDictionary;
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  NSArray *keys = nil;
  NSEnumerator *keyEnum = nil;
  DKDictEntryTypeArgument *pairArgument = (DKDictEntryTypeArgument*)[self elementTypeArgument];
  id element = nil;

  DBusMessageIter subIter;
  if (nil == object)
  {
    object = [NSDictionary dictionary];
  }

  NSAssert1(([object respondsToSelector: @selector(allKeys)]
    && [object respondsToSelector: @selector(objectForKey:)]),
    @"Cannot marshall non key/value dictionary '%@' to D-Bus iterator.",
    object);

  DK_ITER_OPEN_CONTAINER(iter, DBUS_TYPE_ARRAY, [[pairArgument DBusTypeSignature] UTF8String], &subIter);

  keys = [object allKeys];
  keyEnum = [keys objectEnumerator];

  NS_DURING
  {
    while (nil != (element = [keyEnum nextObject]))
    {
      [pairArgument marshallObject: [object objectForKey: element]
                            forKey: element
		      intoIterator: &subIter];
    }
  }
  NS_HANDLER
  {
    // Something already went wrong and we don't care for a potential OOM error
    // from dbus_message_iter_close_container();
    dbus_message_iter_close_container(iter, &subIter);
    [localException raise];
  }
  NS_ENDHANDLER

  DK_ITER_CLOSE_CONTAINER(iter, &subIter);
}
@end

@implementation DKStructTypeArgument
-(id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  NSMutableArray *theArray = [NSMutableArray new];
  NSArray *returnArray = nil;
  NSNull *theNull = [NSNull null];
  NSUInteger index = 0;
  NSUInteger count = [children count];
  DBusMessageIter subIter;
  NSAssert((DBUS_TYPE_STRUCT == dbus_message_iter_get_arg_type(iter)),
    @"Type mismatch between introspection data and D-Bus message.");

  dbus_message_iter_recurse(iter,&subIter);
  do
  {
    id obj = [[children objectAtIndex: index] unmarshalledObjectFromIterator: &subIter];
    if (nil == obj)
    {
      obj = theNull;
    }
    [theArray addObject: obj];
  } while (dbus_message_iter_next(&subIter) && (index < count));

  returnArray = [NSArray arrayWithArray: theArray];
  [theArray release];
  return returnArray;
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  DBusMessageIter subIter;
  NSEnumerator *structEnum = nil;
  NSUInteger childCount = [children count];


  if (nil != object)
  {
    NSAssert1(([object respondsToSelector: @selector(count)]
      && [object respondsToSelector: @selector(objectEnumerator)]),
      @"Object '%@' cannot be marshalled as D-Bus struct.",
      object);
    NSAssert3(([object count] == childCount),
      @"Could not marshall object '%@' as D-Bus struct: Expected %lu members, got %lu.",
      object,
      [object count],
      childCount);
  }

  DK_ITER_OPEN_CONTAINER(iter, DBUS_TYPE_STRUCT, NULL, &subIter);

  if (nil != object)
  {
    structEnum = [object objectEnumerator];

    NS_DURING
    {
      NSUInteger index = 0;
      id member = nil;
      while ((nil != (member = [structEnum nextObject]))
        && (index < childCount))
      {
        [[children objectAtIndex: index] marshallObject: member
                                           intoIterator: &subIter];
      index++;
      }
    }
    NS_HANDLER
    {
      dbus_message_iter_close_container(iter, &subIter);
      [localException raise];
    }
    NS_ENDHANDLER
  }
  DK_ITER_CLOSE_CONTAINER(iter, &subIter);
}
@end


@implementation DKVariantTypeArgument

- (NSString*)validSubSignatureOrVariantForEnumerator: (NSEnumerator*)theEnum
{
  id element = [theEnum nextObject];
  NSString *thisSig = [[self DKArgumentWithObject: element] DBusTypeSignature];
  NSString *nextSig = thisSig;

  // For homogenous collection, we can the proper signature, for non-homogenous
  // ones, we need to pass down the variant type.
  BOOL isHomogenous = YES;
  while ((nil != (element = [theEnum nextObject]))
    && (YES == isHomogenous))
  {
    thisSig = nextSig;
    nextSig = [[self DKArgumentWithObject: element] DBusTypeSignature];
    isHomogenous = [thisSig isEqualToString: nextSig];
  }

  if (isHomogenous)
  {
    return thisSig;
  }
  else
  {
    return @"v";
  }

}

- (DKArgument*) DKArgumentWithObject: (id)object
{
  if (([object respondsToSelector: @selector(keyEnumerator)])
    && ([object respondsToSelector: @selector(objectEnumerator)]))
  {
    NSEnumerator *keyEnum = [object keyEnumerator];
    NSEnumerator *objEnum = [object objectEnumerator];
    NSString *keySig = [self validSubSignatureOrVariantForEnumerator: keyEnum];
    NSString *objSig = [self validSubSignatureOrVariantForEnumerator: objEnum];
    NSString *theSig = [NSString stringWithFormat: @"a{%@%@}", keySig, objSig];
    DKArgument *subArg = [[[DKArgument alloc] initWithDBusSignature: [theSig UTF8String]
                                                               name: nil
                                                             parent: self] autorelease];
    if (nil == subArg)
    {
      // This might happen if the dictionary could not properly be represented as
      // a D-Bus dictionary (i.e. it has keys of complex type. In this case, we
      // fall back to representing it as an array of structs:
      theSig = [NSString stringWithFormat: @"a(%@%@)", keySig, objSig];
      subArg = [[[DKArgument alloc] initWithDBusSignature: [theSig UTF8String]
                                                     name: nil
                                                   parent: self] autorelease];
    }
    return subArg;
  }
  else if ([object respondsToSelector: @selector(objectEnumerator)])
  {
    NSEnumerator *theEnum = [object objectEnumerator];
    NSString *subSig = [self validSubSignatureOrVariantForEnumerator: theEnum];
    return [[[DKArgument alloc] initWithDBusSignature: [[@"a" stringByAppendingString: subSig] UTF8String]
                                                 name: nil
                                               parent: self] autorelease];
  }
  else if ([object isKindOfClass: [DKProxy class]])
  {
    DKProxy *rootProxy = [self proxyParent];
    if ([rootProxy hasSameScopeAs: object])
    {
      return [[[DKArgument alloc] initWithDBusSignature: DBUS_TYPE_OBJECT_PATH_AS_STRING
                                                   name: nil
                                                 parent: self] autorelease];
    }
  }
  else
  {
    // Simple types are quite straightforward, if we can find an appropriate
    // deserialization selector.
    int type = DKDBusTypeForUnboxingObject(object);
    if ((DBUS_TYPE_INVALID != type) && (DBUS_TYPE_OBJECT_PATH != type))
    {
      return [[DKArgument alloc] initWithDBusSignature: (char*)&type
                                                  name: nil
                                                parent: self];
    }
    else if ([[self proxyParent] _isLocal])
    {
      // If this fails, and the proxy from which this argument derives is an
      // outgoing proxy, we can export it as an object path.
      return [[[DKArgument alloc] initWithDBusSignature: DBUS_TYPE_OBJECT_PATH_AS_STRING
                                                   name: nil
                                                 parent: self] autorelease];
    }
  }
  // Too bad, we have apparantely no chance to generate an argument tree for
  // this object.
  return nil;
}

- (id) unmarshalledObjectFromIterator: (DBusMessageIter*)iter
{
  char *theSig = NULL;
  DBusMessageIter subIter;
  DKArgument *theArgument = nil;
  id theValue = nil;
  NSAssert((DBUS_TYPE_VARIANT == dbus_message_iter_get_arg_type(iter)),
    @"Type mismatch between introspection data and D-Bus message.");

  dbus_message_iter_recurse(iter,&subIter);
  theSig = dbus_message_iter_get_signature(&subIter);
  theArgument = [[DKArgument alloc] initWithDBusSignature: theSig
                                                     name: nil
                                                   parent: self];
  theValue = [theArgument unmarshalledObjectFromIterator: &subIter];
  [theArgument release];
  dbus_free(theSig);
  return theValue;
}

- (void) marshallObject: (id)object
           intoIterator: (DBusMessageIter*)iter
{
  DKArgument *subArg = [self DKArgumentWithObject: object];
  DBusMessageIter subIter;

  if (nil != object)
  {
    NSAssert1(subArg,
      @"Could not marshall object %@ as D-Bus variant type",
      subArg);
  }

  DK_ITER_OPEN_CONTAINER(iter, DBUS_TYPE_VARIANT, [[subArg DBusTypeSignature] UTF8String], &subIter);


  if (nil != object)
  {
    NS_DURING
    {
      [subArg marshallObject: object
                intoIterator: &subIter];
    }
    NS_HANDLER
    {
      dbus_message_iter_close_container(iter, &subIter);
      [localException raise];
    }
    NS_ENDHANDLER
  }
  DK_ITER_CLOSE_CONTAINER(iter, &subIter);
}
@end

@implementation DKDictEntryTypeArgument
- (id)initWithIterator: (DBusSignatureIter*)iterator
                  name: (NSString*)_name
                parent: (id)_parent
{
  NSUInteger childCount = 0;
  if (nil == (self = [super initWithIterator: iterator
                                        name: _name
                                      parent: _parent]))
  {
    return nil;
  }

  childCount = [children count];

  // Dictionaries have exactly two types:
  if (childCount != 2)
  {
    NSWarnMLog(@"Invalid number of children (%lu) for D-Bus dict entry argument. Ignoring argument.",
      childCount);
    [self release];
    return nil;
  }
  else if ([[children objectAtIndex: 0] isContainerType])
  {
    NSWarnMLog(@"Invalid (complex) type '%@' as dict entry key. Ignoring argument.",
      [[children objectAtIndex: 0] DBusTypeSignature]);
    [self release];
    return nil;
  }

  return self;
}

- (DKArgument*)keyArgument
{
  return [children objectAtIndex: 0];
}

- (DKArgument*)valueArgument
{
  return [children objectAtIndex: 1];
}

- (void) unmarshallFromIterator: (DBusMessageIter*)iter
                          value: (id*)value
                            key: (id*)key
{
  DBusMessageIter subIter;
  NSAssert((DBUS_TYPE_DICT_ENTRY == dbus_message_iter_get_arg_type(iter)),
    @"Type mismatch between introspection data and D-Bus message.");

  dbus_message_iter_recurse(iter, &subIter);

  *key = [[self keyArgument]  unmarshalledObjectFromIterator: &subIter];

  if (dbus_message_iter_next(&subIter))
  {
    *value = [[self valueArgument] unmarshalledObjectFromIterator: &subIter];
  }
  else
  {
    *value = nil;
  }
  return;
}
- (void) marshallObject: (id)object
                 forKey: (id)key
           intoIterator: (DBusMessageIter*)iter
{
  DBusMessageIter subIter;
  DK_ITER_OPEN_CONTAINER(iter, DBUS_TYPE_DICT_ENTRY, NULL, &subIter);

  if ((nil != key) && (nil != object))
  {
    NS_DURING
    {
      [[self keyArgument] marshallObject: key
                            intoIterator: &subIter];
      [[self valueArgument] marshallObject: object
                              intoIterator: &subIter];
    }
    NS_HANDLER
    {
      // Again, we don't care for OOM here because we already failed.
      dbus_message_iter_close_container(iter, &subIter);
      [localException raise];
    }
    NS_ENDHANDLER
  }
  DK_ITER_CLOSE_CONTAINER(iter, &subIter);
}
@end
