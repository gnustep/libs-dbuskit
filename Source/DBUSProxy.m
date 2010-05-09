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

#include <Foundation/NSArray.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSException.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSString.h>
#include <Foundation/NSXMLParser.h>
#include <objc/Protocol.h>

#include "DBUSProxy.h"
#include "DBUSMessage.h"
#include "DBUSConnection.h"

@interface DBUSMethodParser: NSObject
{
  NSMutableDictionary *interfaces;
  NSMutableDictionary *methods;
  NSMutableArray *args;
}

- (NSDictionary *)interfaces;

@end

@implementation DBUSProxy

- (id) initForConnection: (DBUSConnection *)connection
              withTarget: (NSString *)theTarget
                    name: (NSString *)theName
            andInterface: (NSString *)theInterface
{
  ASSIGN(conn, connection);
  ASSIGN(target, theTarget);
  ASSIGN(name, theName);
  ASSIGN(interface, theInterface);
  return self;
}

- (void) dealloc
{
  RELEASE(conn);
  RELEASE(target);
  RELEASE(name);
  [super dealloc];
}

- (NSString*) target
{
  return target;
}

- (NSString*) name
{
  return name;
}

- (NSString*) interface
{
  return interface;
}

- (void) setInterface: (NSString*)theInterface
{
   ASSIGN(interface, theInterface);   
}

- (NSString*) interfaceForMethodName: (NSString*)mName
{
  if ([mName isEqualToString: @"Introspect"])
    {
      return @"org.freedesktop.DBus.Introspectable";
    }
// FIXME: Try to get the interface name from the protocol
  else
    {
      return [self interface];
    }
}

// Overrides
- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  DBUSMessage *message;

  if (sel_eq([anInvocation selector], @selector(respondsToSelector:)))
    {
      BOOL res = NO;
      // FIXME
      [anInvocation setReturnValue: &res];
      return;
    }
  else if (sel_eq([anInvocation selector], @selector(conformsToProtocol:)))
    {
      BOOL res = NO;
      // FIXME
      [anInvocation setReturnValue: &res];
      return;
    }
  else if (sel_eq([anInvocation selector], @selector(isKindOfClass:)))
    {
      BOOL res = NO;
      // FIXME
      [anInvocation setReturnValue: &res];
      return;
    }
  else if (sel_eq([anInvocation selector], @selector(isMemberOfClass:)))
    {
      BOOL res = NO;
      // FIXME
      [anInvocation setReturnValue: &res];
      return;
    }

  message = [DBUSMessage dbusMessageFor: self
                         invocation: anInvocation];
  if (nil == message) 
    { 
      NSLog(@"Message Null\n");
      exit(1);
    }

  [conn forwardInvocation: message invocation: anInvocation];
}

- (NSMethodSignature *) methodSignatureForSelector: (SEL)aSelector
{
  NSMethodSignature *sig;
  struct objc_method	*mth;

  // This is copied from NSProxy, but it cannot be called directly!
  if (aSelector == 0)
    [NSException raise: NSInvalidArgumentException
		format: @"%@ null selector given", NSStringFromSelector(_cmd)];

  mth = GSGetMethod(GSObjCClass(self), aSelector, YES, YES);
  if (mth != 0)
    {
      return [NSMethodSignature signatureWithObjCTypes:mth->method_types];
    }

  // This is copied from NSDistantObject
  if (protocol != nil)
	  {
      const char	*types = 0;
      struct objc_method_description* mth;

      /* Older gcc versions may not initialise Protocol objects properly
       * so we have an evil hack which checks for a known bad value of
       * the class pointer, and uses an internal function
       * (implemented in NSObject.m) to examine the protocol contents
       * without sending any ObjectiveC message to it.
       */
      if ((uintptr_t)GSObjCClass(protocol) == 0x2)
	      {
          extern struct objc_method_description*
              GSDescriptionForInstanceMethod();
          mth = GSDescriptionForInstanceMethod(protocol, aSelector);
        }
      else
	      {
          mth = [protocol descriptionForInstanceMethod: aSelector];
        }
      if (mth == 0)
	      {
          if ((uintptr_t)GSObjCClass(protocol) == 0x2)
            {
              extern struct objc_method_description*
                  GSDescriptionForClassMethod();
              mth = GSDescriptionForClassMethod(protocol, aSelector);
            }
          else
            {
              mth = [protocol descriptionForClassMethod: aSelector];
            }
        }
      if (mth != 0)
	      {
          types = mth->types;
        }
      if (types)
        return [NSMethodSignature signatureWithObjCTypes: types];
    }



  NSLog(@"methodSignatureForSelector called with %@", NSStringFromSelector(aSelector));
  if (sel_eq(aSelector, @selector(Introspect)))
    {
      char *t;
  
      // Signature for method that returns char* and has no additional arguments
      t = "*8@0:4";
      sig = [NSMethodSignature signatureWithObjCTypes: t];
      if (sig != nil)
        {
          return sig;
        }
    }
  else
    {
      /* 
         Call Introspect to get the interface definitions. Parse the XML and build up 
         a list of interfaces and their methods with the sigantures and use that to 
         determine the interface and signature to use....
       */

    }

  return nil;
}

- (void) setProtocolForProxy: (Protocol*)aProtocol
{
  protocol = aProtocol;
}

- (DBUSConnection*) connectionForProxy
{
  return conn;
}

- (BOOL)buildMethodCache
{
  char *xmlChars;
  int len;
  NSData *data;
  NSXMLParser *parser;
  DBUSMethodParser *delegate;

  xmlChars = [self Introspect];
  len = strlen(xmlChars);
  data = [[NSData alloc] initWithBytes: xmlChars length: len];
  parser = [[NSXMLParser alloc] initWithData: data];
  RELEASE(data);
  delegate = [[DBUSMethodParser alloc] init];
  [parser setDelegate: delegate];
  [parser parse];
  RELEASE(parser);
  RELEASE(delegate);

  return YES;
}

@end

@implementation DBUSProxy (Introspectable)

/*
  This implementation gives us the signature for this method.
 */
- (char*)Introspect
{
  NSMethodSignature	*sig;
  NSInvocation *inv;
  char *ret;

  sig = [self methodSignatureForSelector: _cmd];
  inv = [NSInvocation invocationWithMethodSignature: sig];
  [inv setSelector: _cmd];
  [self forwardInvocation: inv];
  [inv getReturnValue: &ret];
  return ret;
}

@end

@implementation DBUSMethodParser 

- (id)init
{
  return self;
}

- (void)dealloc
{
  RELEASE(interfaces);
  RELEASE(methods);
  RELEASE(args);
  [super dealloc];
}

- (NSDictionary *)interfaces
{
  return interfaces;
}

- (void) parser: (NSXMLParser*)aParser
  didStartElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
  attributes: (NSDictionary*)anAttributeDict
{
  NSLog(@"Got element %@ with attrs %@", anElementName, anAttributeDict);

  if ([@"node" isEqualToString: anElementName])
    {
      interfaces = [[NSMutableDictionary alloc] init];
    }
  else if ([@"interface" isEqualToString: anElementName])
    {
      NSString *name;

      name = [anAttributeDict objectForKey: @"name"];
      RELEASE(methods);
      methods = [[NSMutableDictionary alloc] init];
      [interfaces setObject: methods forKey: name];
    }
  else if ([@"method" isEqualToString: anElementName])
    {
      NSString *name;

      name = [anAttributeDict objectForKey: @"name"];
      RELEASE(args);
      args = [[NSMutableArray alloc] init];
      [methods setObject: args forKey: name];
    }
  else if ([@"arg" isEqualToString: anElementName])
    {
      [args addObject: anAttributeDict];
    }
  else if ([@"signal" isEqualToString: anElementName])
    {
      // These get ignored
      RELEASE(args);
      args = [[NSMutableArray alloc] init];
    }
}

- (void) parser: (NSXMLParser*)aParser
  didEndElement: (NSString*)anElementName
  namespaceURI: (NSString*)aNamespaceURI
  qualifiedName: (NSString*)aQualifierName
{
  if ([@"method" isEqualToString: anElementName])
    {
      // Convert the args into a Method signature
    }
}

- (void) parserDidEndDocument: (NSXMLParser*)aParser
{
//  NSLog(@"intefaces %@", interfaces);
}

@end
