/** Implementation of the DKProxy class representing D-Bus objects on the
    GNUstep side.
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   Created: May 2010

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

#import "DKEndpoint.h"
#import "DKInterface.h"
#import "DKIntrospectionParserDelegate.h"
#import "DKMethod.h"
#import "DKMethodCall.h"
#import "DBusKit/DKProxy.h"

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSString.h>
#import <Foundation/NSThread.h>
#import <Foundation/NSXMLParser.h>
#import <GNUstepBase/NSDebug+GNUstepBase.h>


/*
 * Definitions of the strings used for selector mangling.
 */
#define SEL_MANGLE_IFSTART_STRING @"_DKIf_"
#define SEL_MANGLE_IFEND_STRING @"_DKIfEnd_"

enum
{
  NO_TABLES,
  NO_CACHE,
  HAVE_CACHE
};

@interface DKProxy (DKProxyPrivate)

- (void)_setupTables;
- (DKMethod*)_methodForSelector: (SEL)aSelector
                          block: (BOOL)doBlock;
- (void)_buildMethodCache;
- (void)_installIntrospectionMethod;
- (void)_installMethod: (DKMethod*)aMethod
           inInterface: (DKInterface*)anInterface
      forSelectorNamed: (NSString*)selName;

- (DKEndpoint*)_endpoint;
- (NSString*)_service;
- (NSString*)_path;
- (BOOL)_isLocal;
/* Define introspect on ourselves. */
- (NSString*)Introspect;
@end

@implementation DKProxy

+ (void)initialize
{
  if ([DKProxy class] == self)
  {
    // Trigger generation of static introspection method:
    [DKMethod class];
  }

}

+ (id)proxyWithEndpoint: (DKEndpoint*)anEndpoint
             andService: (NSString*)aService
                andPath: (NSString*)aPath
{
  return [[[self alloc] initWithEndpoint: anEndpoint
                              andService: aService
                                 andPath: aPath] autorelease];
}

- (id)initWithEndpoint: (DKEndpoint*)anEndpoint
            andService: (NSString*)aService
               andPath: (NSString*)aPath
{
  // This class derives from NSProxy, hence no call to -[super init].
  if ((((nil == anEndpoint)) || (nil == aService)) || (nil == aPath))
  {
    [self release];
    return nil;
  }
  ASSIGNCOPY(service, aService);
  ASSIGNCOPY(path, aPath);
  ASSIGN(endpoint, anEndpoint);
  tableLock = [[NSConditionLock alloc] initWithCondition: NO_TABLES];
  [self _setupTables];
  [self _installIntrospectionMethod];
  return self;
}

- (id)initWithCoder: (NSCoder*)coder
{
  if ([coder allowsKeyedCoding])
  {
    endpoint = [coder decodeObjectForKey: @"DKProxyEndpoint"];
    service = [coder decodeObjectForKey: @"DKProxyService"];
    path = [coder decodeObjectForKey: @"DKProxyPath"];
  }
  else
  {
    [coder decodeValueOfObjCType: @encode(id) at: &endpoint];
    [coder decodeValueOfObjCType: @encode(id) at: &service];
    [coder decodeValueOfObjCType: @encode(id) at: &path];
  }
  tableLock = [[NSConditionLock alloc] initWithCondition: NO_TABLES];
  [self _setupTables];
  [self _installIntrospectionMethod];
  return self;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  if ([coder allowsKeyedCoding])
  {
    [coder encodeObject: endpoint forKey: @"DKProxyEndpoint"];
    [coder encodeObject: service forKey: @"DKProxyService"];
    [coder encodeObject: path forKey: @"DKProxyPath"];
  }
  else
  {
    [coder encodeObject: endpoint];
    [coder encodeObject: service];
    [coder encodeObject: path];
  }
}

/**
 * Overrides the implementation in NSProxy, which would wrap this proxy in an
 * NSDistantObject
 */
- (id)replacementObjectForPortCoder: (NSPortCoder*)coder
{
  return self;
}

/**
 * Overrides NSProxy.
 */
- (Class)classForPortCoder
{
  return [DKProxy class];
}



/**
 * Returns the DKMethod that handles the selector.
 */
- (DKMethod*)DBusMethodForSelector: (SEL)selector
{
  if (0 == selector)
  {
    return nil;
  }
  return NSMapGet(selectorToMethodMap, selector);
}

- (void)setPrimaryDBusInterface: (NSString*)anInterface
{
  if (interfaces == nil)
  {
    // The interfaces have not yet been resolved, so we temporarily store the
    // string until the method resolution has run.
    ASSIGN(activeInterface, anInterface);
  }
  else
  {
    DKInterface *theIf = [interfaces objectForKey: anInterface];
    ASSIGN(activeInterface, theIf);
  }
}

/**
 * Returns the interface corresponding to the mangled version in which all dots
 * have been replaced with underscores.
 */
- (NSString*)DBusInterfaceForMangledString: (NSString*)string
{
  DKInterface *anIf = nil;
  NSEnumerator *enumerator = nil;
  if (nil == string)
  {
    return nil;
  }

  enumerator =[interfaces objectEnumerator];

  while (nil != (anIf = [enumerator nextObject]))
  {
    if ([string isEqualToString: [anIf mangledName]])
    {
      return [anIf name];
    }
  }
  return nil;
}

/**
 * This method strips the metadata mangled into the selector string and
 * returns it at shallBox and interface.
 */

- (SEL)_unmangledSelector: (SEL)selector
                interface: (NSString**)interface
{
  NSMutableString *selectorString = [NSStringFromSelector(selector) mutableCopy];
  SEL unmangledSelector = 0;

  NSRange ifStartRange = [selectorString rangeOfString: SEL_MANGLE_IFSTART_STRING];
  NSRange ifEndRange = [selectorString rangeOfString: SEL_MANGLE_IFEND_STRING];

  if (0 == selector)
  {
    return 0;
  }

  // Sanity check for presence and order of both the starting and the ending
  // string.
  if ((NSNotFound != ifStartRange.location)
    && (NSNotFound != ifEndRange.location)
    && (NSMaxRange(ifStartRange) < ifEndRange.location))
  {
    // Do not dereference NULL
    if (interface != NULL)
    {
      // Calculate the range of the interface string between the two:
      NSUInteger ifIndex = NSMaxRange(ifStartRange);
      NSUInteger ifLength = (ifEndRange.location - ifIndex);
      NSRange ifRange = NSMakeRange(ifIndex, ifLength);

      // Extract and unmangle the information
      NSString *mangledIf = [selectorString substringWithRange: ifRange];
      *interface = [self DBusInterfaceForMangledString: mangledIf];
    }

    // Throw away the whole _DKIf_*_DKEndIf_ portion.
    [selectorString deleteCharactersInRange: NSUnionRange(ifStartRange, ifEndRange)];
  }

  unmangledSelector = NSSelectorFromString(selectorString);
  [selectorString release];
  return unmangledSelector;
}

- (NSMethodSignature*)methodSignatureForSelector: (SEL)aSelector
{
  /*
   * For simple cases we can simply look up the selector in the table and return
   * the signature from the associated method.
   */
  DKMethod *method = [self _methodForSelector: aSelector
                                        block: NO];
  const char *types = NULL;
  NSMethodSignature *theSig = nil;
# if HAVE_TYPED_SELECTORS == 0
  // Without typed selectors, we have the old gcc libobjc which, in fact, has
  // typed selectors but no API to access them. But we can still copy them from
  // the SEL structure.
  types = aSelector->sel_types;
# else
  types = sel_getType_np(aSelector);
# endif

  // Build a signature with the types:
  theSig = [NSMethodSignature signatureWithObjCTypes: types];

  /*
   * Second chance to find the method: Fall back to the untyped version.
   */
  if (nil == method)
  {
    method = [self _methodForSelector: sel_getUid(sel_getName(aSelector))
                                block: NO];
  }

  /*
   * Third chance to find the method: Remove mangling constructs from the
   * selector string.
   */
  if (nil == method)
  {
    NSString *interface = nil;
    SEL unmangledSel = [self _unmangledSelector: aSelector
                                      interface: &interface];
    if (0 == unmangledSel)
    {
      // We can't do anything then.
      return nil;
    }

    if (nil != interface)
    {
      // The interface was specified. Retrieve the corresponding method;
      method = [(DKInterface*)[interfaces objectForKey: interface] methodForSelector: unmangledSel];
    }
    else
    {
      // No interface, so we try the standard dispatch table:
      method = [self _methodForSelector: unmangledSel
                                  block: NO];
    }
  }


  // Finally check whether we have a sensible method and signature:
  if (nil == method)
  {
    // Bad luck, the method is not there:
    return nil;
  }
  else if ([method isValidForMethodSignature: theSig])
  {
    // Good, the method can handle the signature for which we are being called:
    return theSig;
  }
  else
  {
    // Bad luck, we got a method, but it is not compatible with this method
    // signature:
    [NSException raise: @"DKInvalidArgumentException"
                format: @"D-Bus object %@ for service %@: Mismatched method signature.",
      path,
      service];
  }

  return nil;
}

- (DKMethod*) _methodForSelector: (SEL)aSel
                           block: (BOOL)doBlock
{
  DKMethod *m = nil;
  BOOL isIntrospect = [@"Introspect" isEqualToString: NSStringFromSelector(aSel)];
  if ([activeInterface isKindOfClass: [DKInterface class]])
  {
    // If an interface was marked active, try to find the selector there first
    // (the interface will perform its own locking).
    m = [activeInterface methodForSelector: aSel];
  }
  if (nil == m)
  {
    if (isIntrospect || (NO == doBlock))
    {
      // For the introspection selector, just lock the table because the
      // introspection selector has been installed on init time. Also, when
      // doBlock == NO, we won't wait for the correct state but simply lock the
      // table.
      [tableLock lock];
    }
    else if (doBlock)
    {

      // Else, we need to wait for the correct state to be signaled by the
      // caching thread.
      [tableLock lockWhenCondition: HAVE_CACHE];
    }
    m = NSMapGet(selectorToMethodMap, aSel);
    [tableLock unlock];
  }

  // If we could not find a method for the selector, we want to trigger building
  // the cache, but only if we are not looking for the introspection selector.
  if (((nil == m) && (HAVE_CACHE != [tableLock condition]))
    && (NO == isIntrospect))
  {
    [self _buildMethodCache];

    // Retry, but this time, block until the introspection data is resolved.
    m = [self _methodForSelector: aSel
                           block: YES];
  }
  return m;
}

- (void)forwardInvocation: (NSInvocation*)inv
{
# if HAVE_TYPED_SELECTORS == 1
  SEL selector = [inv selector];
# else
  // If we cannot generate typed selectors, only test for the untyped version
  SEL selector = sel_getUid(sel_getName([inv selector]));
# endif

  NSMethodSignature *signature = [inv methodSignature];
  NSString *interface = nil;
  DKMethod *method = [self _methodForSelector: selector
                                        block: YES];
  DKMethodCall *call = nil;

  if (nil == method)
  {
    SEL newSel = 0;
    newSel = [self _unmangledSelector: selector
                            interface: &interface];
    if (0 != newSel)
    {
      [inv setSelector: newSel];
      if (nil != interface)
      {
	method = [(DKInterface*)[interfaces objectForKey: interface] methodForSelector: newSel];
      }
      else
      {
	method = [self _methodForSelector: newSel
	                            block: YES];
      }
    }
  }
  if (nil == method)
  {
    // Test whether this selector is already untyped:
    SEL newSel = sel_getUid(sel_getName(selector));
    if (sel_isEqual(newSel, selector))
    {
      // If so, we cannot do anything more:
      [NSException raise: @"DKInvalidArgumentException"
                  format: @"D-Bus object %@ for service %@ does not recognize %@",
        path,
        service,
       NSStringFromSelector(selector)];
    }
    //else, we can start again with the new selector
    [inv setSelector: newSel];
    [self forwardInvocation: inv];
  }

  if (NO == [method isValidForMethodSignature: signature])
  {
    [NSException raise: @"DKInvalidArgumentException"
                format: @"D-Bus object %@ for service %@: Mismatched method signature.",
      path,
      service];
  }

  call = [[DKMethodCall alloc] initWithProxy: self
                                      method: method
                                  invocation: inv];

  //TODO: Implement asynchronous method calls using futures
  [call sendSynchronouslyAndWaitUntil: 0];
}

- (BOOL)isKindOfClass: (Class)aClass
{
  if (aClass == [DKProxy class])
  {
    return YES;
  }
  return NO;
}

- (DKEndpoint*)_endpoint
{
  return endpoint;
}

- (NSString*)_service
{
  return service;
}

- (NSString*)_path
{
  return path;
}

- (BOOL)_isLocal
{
  // True only for outgoing proxies representing local objects.
  return NO;
}

- (NSDictionary*)_interfaces
{
  return [NSDictionary dictionaryWithDictionary: interfaces];
}

- (id) proxyParent
{
  return self;
}

- (BOOL) hasSameScopeAs: (DKProxy*)aProxy
{
  BOOL sameService = [service isEqualToString: [aProxy _service]];
  BOOL sameEndpoint = [endpoint isEqual: [aProxy _endpoint]];
  return (sameService && sameEndpoint);
}

- (void)_installMethod: (DKMethod*)aMethod
           inInterface: (DKInterface*)anInterface
           forSelector: (SEL)aSel
{
  // NOTE: The caller is responsible for obtaining the tableLock
  if ((0 == aSel) || (nil == aMethod))
  {
    NSWarnMLog(@"Not inserting invalid selector/method pair.");
    return;
  }
  if (NULL != NSMapInsertIfAbsent(selectorToMethodMap, aSel, aMethod))
  {
    NSDebugMLog(@"Overloaded selector %@ for method %@",
      NSStringFromSelector(aSel),
      aMethod);
  }

  [anInterface installMethod: aMethod
                 forSelector: aSel];
  // NOTE: The caller is responsible for unlocking the tables.
}

- (void)_installMethod: (DKMethod*)aMethod
           inInterface: (DKInterface*)theIf
      forSelectorNamed: (NSString*)selName
{
  // NOTE: The caller is responsible for obtaining the tableLock

  const char* selectorString;
  SEL untypedSelector = 0;

# if HAVE_TYPED_SELECTORS == 1
  SEL typedBoxingSelector = 0;
  SEL typedNonBoxingSelector = 0;
  const char* boxedTypes = [aMethod objCTypesBoxed: YES];
  const char* nonBoxedTypes = [aMethod objCTypesBoxed: NO];
# endif

  if (nil == selName)
  {
    selectorString = [[aMethod selectorString] UTF8String];
  }
  else
  {
    selectorString = [selName UTF8String];
  }

  if (NULL == selectorString)
  {
    NSWarnMLog(@"Cannot register selector with empty name for method %@");
    return;
  }

  untypedSelector = sel_registerName(selectorString);
  [self _installMethod: aMethod
           inInterface: theIf
	   forSelector: untypedSelector];
  NSDebugMLog(@"Registered %s as %p (untyped)",
    selectorString,
    untypedSelector);
# if HAVE_TYPED_SELECTORS == 1
  if (NULL == boxedTypes)
  {
    NSWarnMLog(@"Not registering typed selector for %@ (empty type string)",
      aMethod);
  }
  else
  {
    typedBoxingSelector = sel_registerTypedName_np(selectorString, boxedTypes);
    [self _installMethod: aMethod
             inInterface: theIf
             forSelector: typedBoxingSelector];
  NSDebugMLog(@"Registered %s as %p (%s)",
    selectorString,
    typedBoxingSelector,
    boxedTypes);
  }
  if (NULL == nonBoxedTypes)
  {
    NSWarnMLog(@"Not registering typed selector for %@ (empty type string)",
      aMethod);
  }
  else
  {
    typedNonBoxingSelector = sel_registerTypedName_np(selectorString, nonBoxedTypes);
    [self _installMethod: aMethod
             inInterface: theIf
             forSelector: typedNonBoxingSelector];
  NSDebugMLog(@"Registered %s as %p (%s)",
    selectorString,
    typedNonBoxingSelector,
    nonBoxedTypes);
  }
# endif
  // NOTE: The caller is responsible for unlocking the tables.
}

- (void) _installIntrospectionMethod
{
  if ([tableLock tryLockWhenCondition: NO_CACHE])
  {
    [self _installMethod: _DKMethodIntrospect
             inInterface: nil
        forSelectorNamed: nil];
    [tableLock unlockWithCondition: NO_CACHE];
  }
}

- (void)_installAllMethodsFromInterface: (DKInterface*)theIf
{
  NSEnumerator *methEnum = [[theIf methods] objectEnumerator];
  DKMethod *theMethod = nil;
  //NOTE: The caller is responsible for obtaining the table lock.
  while (nil != (theMethod = [methEnum nextObject]))
  {
    // TODO: Look aside whether there is a custom selector name set somewhere.
    NSString *theSelName = [theMethod selectorString];
    [self _installMethod: theMethod
             inInterface: theIf
        forSelectorNamed: theSelName];
  }
  // NOTE: The caller is responsible for unlocking the tables.
}


- (void) _installAllMethods
{
  NSEnumerator *ifEnum = [interfaces objectEnumerator];
  DKInterface *theIf = nil;
  [tableLock lock];
  while (nil != (theIf = [ifEnum nextObject]))
  {
    [self _installAllMethodsFromInterface: theIf];
  }

  [tableLock unlockWithCondition: HAVE_CACHE];

}
- (void)_setupTables
{
  if (NULL == selectorToMethodMap)
  {
    if ([tableLock tryLockWhenCondition: NO_TABLES])
    {
      if (NULL == selectorToMethodMap)
      {
	selectorToMethodMap = NSCreateMapTable(NSIntMapKeyCallBacks,
	  NSObjectMapValueCallBacks,
	  10);
      }
      [tableLock unlockWithCondition: NO_CACHE];
    }
  }
}

- (void)setInterfaces: (NSDictionary*)_interfaces
{
  [tableLock lock];
  ASSIGN(interfaces,_interfaces);
  if ([activeInterface isKindOfClass: [NSString class]])
  {
    [self setPrimaryDBusInterface: (NSString*)activeInterface];
  }
  [tableLock unlock];
}

- (void)_buildMethodCache
{
  // Get the introspection data:
  NSData *introspectionData = [[self Introspect] dataUsingEncoding: NSUTF8StringEncoding];

  // Set up parser and delegate (and an autorelease pool to cache autoreleased
  // nodes).
  NSXMLParser *parser = [[NSXMLParser alloc] initWithData: introspectionData];
  DKIntrospectionParserDelegate *delegate = [[DKIntrospectionParserDelegate alloc] initWithParentForNodes: self];
  NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];

  [parser setDelegate: delegate];
  [parser parse];

  // Get the interfaces from the delegate:
  [self setInterfaces: [delegate interfaces]];
  // TODO: Also get the child nodes

  // Cleanup
  [parser release];
  [delegate release];
  [arp release];

  [self _installAllMethods];
}

- (void) dealloc
{
  [endpoint release];
  [service release];
  [path release];
  [tableLock release];
  [interfaces release];
  [activeInterface release];
  [super dealloc];
}

@end
