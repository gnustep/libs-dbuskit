/* 
   Language bindings for d-bus
   Copyright (C) 2007 Free Software Foundation, Inc.

   Written by: Fred Kiefer <FredKiefer@gmx.de>
   Created: January 2007

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/
#include <Foundation/NSInvocation.h>
#include <Foundation/NSString.h>
#include "DBUS.h"

@implementation DBUSMessage

+ (NSString*) methodNameForSelector: (SEL)selector
{
  NSString *name;

  name = NSStringFromSelector(selector);
  return [name stringByReplacingString: @":" withString: @""];
}

// Currently not used
+ (const char*) dbusSignatureToObjC: (const char*)sig
{
  int i;

  i = 0;
  while (sig[i] != 0)
    {
      char type;
      char s;

      type = sig[i];

      switch (type)
        {
          case DBUS_TYPE_INVALID:
            break;
          case DBUS_TYPE_SIGNATURE:
            s = _C_SEL;
            break;
          case DBUS_TYPE_OBJECT_PATH:
            s = _C_ID;
            break;
          case DBUS_TYPE_STRING:
            s = _C_CHARPTR;
            break;
          case DBUS_TYPE_BOOLEAN:
            s = _C_UCHR;
            break;
          case DBUS_TYPE_BYTE:
            s = _C_CHR;
            break;
          case DBUS_TYPE_INT16:
            s = _C_SHT;
            break;
          case DBUS_TYPE_UINT16:
            s = _C_USHT;
            break;
          case DBUS_TYPE_INT32:
            s = _C_INT;
            break;
          case DBUS_TYPE_UINT32:
            s = _C_UINT;
            break;
          case DBUS_TYPE_INT64:
            s = _C_LNG;
            break;
          case DBUS_TYPE_UINT64:
            s = _C_ULNG;
            break;
          case DBUS_TYPE_DOUBLE:
            s = _C_DBL;
            break;
          case DBUS_TYPE_ARRAY:
            s = _C_ARY_B;
            break;
          case DBUS_TYPE_VARIANT:
            s = _C_UNION_B;
            break;
          case DBUS_STRUCT_BEGIN_CHAR:
          case DBUS_STRUCT_END_CHAR:
          case DBUS_DICT_ENTRY_BEGIN_CHAR:
          case DBUS_DICT_ENTRY_END_CHAR:
            break;
        }
    }

  return "";
}

+ (id) dbusMessageFor: (DBUSProxy*)object
           invocation: (NSInvocation*)inv
{
  DBUSMessage *new;
  NSString *mName;
  NSString *interface;

  mName = [self methodNameForSelector: [inv selector]];
  interface = [object interfaceForMethodName: mName];
  new = [[DBUSMessage alloc] initMethodCallWithTarget: [object target]
                             name: [object name]
                             interface: interface
                             andMethodName: mName];
  if (![new setupInvocation: inv])
      {
        RELEASE(new);
        return nil;
      }
  return AUTORELEASE(new);
}

- (id) initWith: (DBusMessage *)aMSG
{
  if (NULL == aMSG) 
    { 
      RELEASE(self);
      return nil;
    }

  msg = aMSG;

  return self;
}

- (id) initMethodCallWithTarget: (NSString*)target
                           name: (NSString*)name
                      interface: (NSString*)interface
                  andMethodName: (NSString*)methodName
{
  // create a new method call and check for errors
  msg = dbus_message_new_method_call([target UTF8String], // target for the method call
                                     [name UTF8String], // object to call on
                                     [interface UTF8String], // interface to call on
                                     [methodName UTF8String]); // method name

  return [self initWith: msg];
}

- (void)dealloc
{
  if (NULL != msg)
    {
      // free message
      dbus_message_unref(msg);
    }   
  [super dealloc];
}

- (BOOL) setupInvocation: (NSInvocation*)inv
{
  DBusMessageIter args;
  NSMethodSignature *sig;
  int count;
  int i;

  // append arguments
  dbus_message_iter_init_append(msg, &args);

  sig = [inv methodSignature];
  count = [sig numberOfArguments];
  for (i = 2; i < count; i++)
    {
      const char *type;

      type = [sig getArgumentTypeAtIndex: i];
      switch (type[0]) 
        {
          case _C_CHARPTR:
            {
              char *param;
              
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_STRING, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_LNG:
            {
              long param;
              
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_INT64, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_ULNG:
            {
              unsigned long param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_UINT64, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_INT:
            {
              int param;
              
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_INT32, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_UINT:
            {
              unsigned int param;
            
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_UINT32, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_SHT:
            {
              short param;
            
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_INT16, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_USHT:
            {
              unsigned short param;
              
              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_UINT16, &param)) 
                {  
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_CHR:
              break;
          case _C_UCHR:
            {
              unsigned char param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_BYTE, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_FLT:
            break;
          case _C_DBL:
            {
              double param;

              [inv getArgument: &param atIndex: i];
              if (!dbus_message_iter_append_basic(&args, DBUS_TYPE_DOUBLE, &param)) 
                {
                  NSLog(@"Out Of Memory!\n"); 
                  return NO;
                }
            }
            break;
          case _C_PTR:
            // FIXME: cannot handle pointers!
            break;
          case _C_ID:
            // FIXME: cannot handle objects!
            // DBUS_TYPE_OBJECT_PATH or DBUS_TYPE_OBJECT_PATH_AS_STRING
            break;
          case _C_VOID:
            // not possible
            break;
          case _C_CLASS:
            // not possible
            break;
          case _C_SEL:
            // not possible
            // DBUS_TYPE_SIGNATURE ?
            break;
          case _C_STRUCT_B:
            // not possible
            // DBUS_TYPE_STRUCT 
            break;
          case _C_UNION_B:
            // not possible
            // DBUS_TYPE_VARIANT 
            break;
          case _C_ARY_B:
            // not possible
            // DBUS_TYPE_ARRAY
            break;

          default:
            break;
        }
    }
  
  return YES;
}

- (BOOL) getResultInto: (NSInvocation*)inv
{
  DBusMessageIter args;

  // read the parameters
  if (!dbus_message_iter_init(msg, &args))
      NSLog(@"Message has no arguments!\n"); 
  else
    {
      int type;
//      int count;
//      dbus_uint32_t level;

      type = dbus_message_iter_get_arg_type(&args);

      switch (type)
        {
          case DBUS_TYPE_BOOLEAN: 
            {
              BOOL res;
              
              dbus_message_iter_get_basic(&args, &res);
              [inv setReturnValue: &res];
            }
            break;
          case DBUS_TYPE_UINT32:
            {
              dbus_uint32_t res;

              dbus_message_iter_get_basic(&args, &res);
              [inv setReturnValue: &res];
            }
            break;
          case DBUS_TYPE_STRING:
            {
              char *res;  

              dbus_message_iter_get_basic(&args, &res);
              [inv setReturnValue: &res];
            }
        // FIXME
        }
    }

  return YES;
}

- (DBusMessage*) msg
{
  return msg;
}

- (const char *)signature
{
  return dbus_message_get_signature(msg);
}
@end
