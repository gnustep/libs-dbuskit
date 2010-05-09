/* -*-objc-*-
  Language bindings for d-bus
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Fred Kiefer <FredKiefer@gmx.de>
  Modified by: Ricardo Correa <r.correa.r@gmail.com>
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

#import "DBUSProxy.h"

#import "DBUSConnection.h"
#import "DBUSIntrospector.h"
#import "DBUSMessage.h"
#import "DBUSMessageCall.h"
#import "DBUSMessageReturn.h"

#import <Foundation/NSData.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSString.h>
#import <objc/Protocol.h>

@implementation DBUSProxy

- (id) init
{
  return self;
}

- (id) initForConnection: (DBUSConnection *)connection
                withName: (NSString *)theName
                    path: (NSString *)thePath
               interface: (NSString *)theInterface
{
  char *intrData;
  NSString *str;
  NSData *data;
  DBUSIntrospector *anIntr;

  ASSIGN(conn, connection);
  ASSIGN(name, theName);
  ASSIGN(path, thePath);
  ASSIGN(interface, theInterface);

  /*
   * This is a DBUS method call and it returns the XML introspection data for
   * the interface
   */

  intrData = [self Introspect];

  if (NULL != intrData)
    {
      str = [NSString stringWithUTF8String: intrData];
      if (str)
        {
          data = [str dataUsingEncoding: NSUnicodeStringEncoding];
          if (data)
            {
              anIntr = [[DBUSIntrospector alloc] initWithData: data];
              if ([anIntr buildMethodCache])
                {
                  ASSIGN(introspector, anIntr);
                }
              else
                {
                  NSDebugLLog(@"DBUSProxy", @"Method cache not built");
                }
              RELEASE(anIntr);
            }
          else
            {
              NSDebugLLog(@"DBUSProxy", @"data = %@", data);
            }
        }
      else
        {
          NSDebugLLog(@"DBUSProxy", @"str = %@", str);
        }
    }
  else
    {
      NSDebugLLog(@"DBUSProxy", @"intrData = %@", intrData);
    }

  [self init];

  return self;
}

- (void) dealloc
{
  RELEASE(conn);
  RELEASE(name);
  RELEASE(path);
  RELEASE(interface);
  RELEASE(introspector);
  [super dealloc];
}

- (NSString *) name
{
  return name;
}

- (NSString *) path
{
  return path;
}

- (NSString *) interface
{
  return interface;
}

- (DBUSConnection*) connectionForProxy
{
  return conn;
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
  NSMethodSignature *sig;

  sig = nil;

  // This is copied from NSProxy, but it cannot be called directly!
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
                format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  if (sel_eq(aSelector, @selector(Introspect:)))
    {
      //sig equivalent to *@:
      sig = [NSMethodSignature signatureWithObjCTypes:
                           [[NSString stringWithFormat: @"%c%c%c",
        _C_CHARPTR, _C_ID, _C_SEL] UTF8String]];
    }

  if (introspector)
    {
      NSString *selName;

      selName = NSStringFromSelector(aSelector);

      if ([self interface])
        {
          sig = [[introspector methodNamed: selName
                               inInterface: [self interface]]
                               methodSignature];
        }
      else
        {
          sig = [[introspector methodNamed: selName] methodSignature];
        }
    }

  NSDebugLLog(@"DBUSProxy", @"Found signature: %@ for selector: %@",
              sig, NSStringFromSelector(aSelector));

  return sig;
}

// Overrides
- (void) forwardInvocation: (NSInvocation*)anInv
{
  DBUSMessageCall *msg;
  DBUSMessageReturn *ret;
  NSString *theInterface;
  SEL theSel;

  theSel = [anInv selector];

  if (NULL == theSel)
    [NSException raise: NSInvalidArgumentException
                format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  if ([NSStringFromSelector(theSel) isEqualToString: @"Introspect"])
    {
      theInterface = @"org.freedesktop.DBus.Introspectable";
    }
  else
    {
      theInterface = [self interface];
    }

  msg = [[[DBUSMessageCall alloc] initMessageCallWithName: [self name]
                                                     path: [self path]
                                                interface: theInterface
                                                 selector: theSel]
                                              autorelease];
  [msg setupInvocation: anInv];

  ret = [conn sendWithReplyAndBlock: msg
                            timeout: -1];
  [ret putResultInto: anInv];
}

- (BOOL) respondsToSelector: (SEL)aSel
{
  BOOL res = NO;

  if (introspector)
    {
      NSString *selName = nil;

      selName = NSStringFromSelector(aSel);

      if ([introspector methodNamed: selName])
        {
          res = YES;
        }
    }

  return res;
}

/* FIXME: Implement this properly
 * - (BOOL) conformsToProtocol: (Protocol *)aProtocol
 */


- (BOOL) isInstance
{
  return YES;
}

@end
