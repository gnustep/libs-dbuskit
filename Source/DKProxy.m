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

#import "DKArgument.h"
#import "DKEndpoint.h"
#import "DKInterface.h"
#import "DKIntrospectionParserDelegate.h"
#import "DKMethod.h"
#import "DKMethodCall.h"
#import "DKProxy+Private.h"

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#undef HAVE_TOYDISPATCH
#define HAVE_TOYDISPATCH 0
#include "AsyncBehavior.h"

#import <Foundation/NSCoder.h>
#import <Foundation/NSData.h>
#import <Foundation/NSException.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSLock.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSRunLoop.h>
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
  HAVE_TABLES,
  HAVE_INTROSPECT,
  WILL_BUILD_CACHE,
  BUILDING_CACHE,
  CACHE_BUILT,
  CACHE_READY
};

@interface DKProxy (DKProxyInternal)

- (void)_setupTables;
- (DKMethod*)_methodForSelector: (SEL)aSelector
                   waitForCache: (BOOL)doWait;
- (void)_buildMethodCache;
- (void)_installIntrospectionMethod;
- (void)_installMethod: (DKMethod*)aMethod
           inInterface: (DKInterface*)anInterface
      forSelectorNamed: (NSString*)selName;

/* Define introspect on ourselves. */
- (NSString*)Introspect;
@end

static inline void DKBuildMethodCacheForProxy(void *p);

DKInterface *_DKInterfaceIntrospectable;

#if HAVE_TOYDISPATCH == 1
dispatch_queue_t introspectionQueue;
static void DKInitIntrospectionThread(void *data);
#endif

@implementation DKProxy

+ (void)initialize
{
  if ([DKProxy class] == self)
  {
    // Trigger generation of static introspection method:
    DKArgument *xmlOutArg = nil;
    DKMethod *introspect = nil;
    _DKInterfaceIntrospectable = [[DKInterface alloc] initWithName: [NSString stringWithUTF8String: DBUS_INTERFACE_INTROSPECTABLE]
                                                            parent: nil];
    introspect = [[DKMethod alloc] initWithName: @"Introspect"
                                         parent: _DKInterfaceIntrospectable];
    xmlOutArg = [[DKArgument alloc] initWithDBusSignature: "s"
                                                     name: @"data"
                                                   parent: introspect];
    [introspect addArgument: xmlOutArg
                  direction: DKArgumentDirectionOut];
    [_DKInterfaceIntrospectable addMethod: introspect];
    [_DKInterfaceIntrospectable installMethod: introspect
                                  forSelector: @selector(Introspect)];
    [introspect release];
    [xmlOutArg release];
    ASYNC_INIT_QUEUE(introspectionQueue, "Introspection parser queue");
    IF_ASYNC(dispatch_async_f(introspectionQueue, NULL, DKInitIntrospectionThread));
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
  tableLock = [[NSLock alloc] init];
  condition = [[NSCondition alloc] init];
  state = NO_TABLES;
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
  tableLock = [[NSLock alloc] init];
  condition = [[NSCondition alloc] init];
  state = NO_TABLES;
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

- (BOOL)conformsToProtocol: (Protocol*)aProto
{
  NSEnumerator *ifEnum = [interfaces objectEnumerator];
  DKInterface *anIf = nil;
  if (protocol_isEqual(@protocol(DKObjectPathNode), aProto))
  {
    return YES;
  }
  while (nil != (anIf = [ifEnum nextObject]))
  {
    if (protocol_isEqual([anIf protocol], aProto))
    {
      return YES;
    }
  }
  return [super conformsToProtocol: aProto];
}

/**
 * Triggers generation of the method cache. This will use ASYNC_IF_POSSIBLE to
 * make  -_buildMethodCache run in a separate thread if libtoydispatch is
 * available. Otherwise, DKBuildMethodCache may be inlined by the compiler and
 * -_buildMethodCache will be executed in the present thread.
 *
 * This is not that much useful if cache generation is requested directly by
 * -methodSignatureForSelector (it will go on and block right away because it
 * needs the cache), but it is quite handy if we want to update the cache
 * periodically.
 */
- (void)DBusBuildMethodCache
{
  // Make sure we don't try to build the cache multiple times:
  [condition lock];
  if (WILL_BUILD_CACHE == state)
  {
    [condition unlock];
    // If we are doing the cache generation in a separate thread, we need to
    // retain ourselves to make sure we don't go away while the cache
    // generation is in progress.
    IF_ASYNC([self retain]);
    ASYNC_IF_POSSIBLE(introspectionQueue, DKBuildMethodCacheForProxy, self);
  }
  else
  {
    [condition unlock];
  }
}

/**
 * Returns the DKMethod that handles the selector.
 */
- (DKMethod*)DBusMethodForSelector: (SEL)selector
{
  DKMethod *m = nil;
  const char* selName;

  if (0 == selector)
  {
    return nil;
  }

  // Normalize the selector to its untyped version:
  selName = sel_getName(selector);
  selector = sel_getUid(selName);

  /*
   * We need the "Introspect" selector to build the method cache and gurantee
   * that there is a method available for it. Hence, we won't wait for the cache
   * to be build when looking it up.
   */
  if (0 == strcmp("Introspect", selName))
  {
    m = [self _methodForSelector: selector
                    waitForCache: NO];
  }

  /*
   * For "Introspect", we now will have a method. We need to look one up for
   * everything else now:
   */
  if (nil == m)
  {
    /* If we don't have a cache yet, we trigger it's generation */
    [condition lock];
    if (HAVE_INTROSPECT >= state)
    {
      state = WILL_BUILD_CACHE;
      [condition unlock];
      [self DBusBuildMethodCache];
    }
    else
    {
      [condition unlock];
    }

    /* Retry, but this time, block until the introspection data is resolved. */
    m = [self _methodForSelector: selector
                    waitForCache: YES];
  }

  return m;
}

- (void)setPrimaryDBusInterface: (NSString*)anInterface
{
  if (interfaces == nil)
  {
    // The interfaces have not yet been resolved, so we temporarily store the
    // string until the method resolution has run.
    ASSIGNCOPY(activeInterface, anInterface);
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
  [tableLock lock];
  enumerator =[interfaces objectEnumerator];

  while (nil != (anIf = [enumerator nextObject]))
  {
    if ([string isEqualToString: [anIf mangledName]])
    {
      [tableLock unlock];
      return [anIf name];
    }
  }
  [tableLock unlock];
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
  DKMethod *method = [self DBusMethodForSelector: aSelector];
  const char *types = NULL;
  NSMethodSignature *theSig = nil;
# if HAVE_TYPED_SELECTORS == 0
  // Without typed selectors (i.e. libobjc2 runtime), we have the old gcc
  // libobjc which has typed selectors but a slightly different API:
  types = sel_get_type(aSelector);
# else
  types = sel_getType_np(aSelector);
# endif

  // Build a signature with the types:
  theSig = [NSMethodSignature signatureWithObjCTypes: types];

  /*
   * Second chance to find the method: Remove mangling constructs from the
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
      [tableLock lock];
      method = [(DKInterface*)[interfaces objectForKey: interface] methodForSelector: unmangledSel];
      [tableLock unlock];
    }
    else
    {
      // No interface, so we try the standard dispatch table:
      method = [self DBusMethodForSelector: unmangledSel];
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
                    waitForCache: (BOOL)doWait
{
  DKMethod *m = nil;

  [condition lock];
  if (doWait)
  {
    // Wait until it is signaled that the cache has been built:
    while (CACHE_READY != state)
    {
      [condition wait];
    }
  }

  [tableLock lock];
  if ([activeInterface isKindOfClass: [DKInterface class]])
  {
    // If an interface was marked active, try to find the selector there first
    // (the interface will perform its own locking).
    m = [activeInterface methodForSelector: aSel];
  }
  if (nil == m)
  {
    m = NSMapGet(selectorToMethodMap, aSel);
  }

  [tableLock unlock];
  [condition unlock];
  return m;
}

- (void)forwardInvocation: (NSInvocation*)inv
{
  SEL selector = [inv selector];
  NSMethodSignature *signature = [inv methodSignature];
  NSString *interface = nil;
  DKMethod *method = [self DBusMethodForSelector: selector];
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
	[tableLock lock];
	method = [(DKInterface*)[interfaces objectForKey: interface] methodForSelector: newSel];
        [tableLock unlock];
      }
      else
      {
	method = [self DBusMethodForSelector: newSel];
      }
    }
  }
  if (nil == method)
  {
    // If so, we cannot do anything more:
    [NSException raise: @"DKInvalidArgumentException"
                format: @"D-Bus object %@ for service %@ does not recognize %@",
      path,
      service,
     NSStringFromSelector(selector)];
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

  // Reschedule the endpoint so that the call does not spin infinitely when a
  // different thread is trying to invoke a D-Bus method and the main thread is
  // blocked.
  [endpoint scheduleInCurrentThread];

  //TODO: Implement asynchronous method calls using futures
  [call sendSynchronouslyAndWaitUntil: 0];
  [call release];
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
  NSDictionary *theDict = nil;
  [tableLock lock];
  theDict = [NSDictionary dictionaryWithDictionary: interfaces];
  [tableLock unlock];
  return theDict;
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

  // NOTE: The caller is responsible for unlocking the tables.
}

- (void) _installIntrospectionMethod
{
  [condition lock];
  while (HAVE_TABLES != state)
  {
    [condition wait];
  }
  [self _addInterface: _DKInterfaceIntrospectable];

  [tableLock lock];
  [self _installMethod: [_DKInterfaceIntrospectable methodForSelector: @selector(Introspect)]
           inInterface: nil
      forSelectorNamed: nil];
  [tableLock unlock];
  state = HAVE_INTROSPECT;
  [condition broadcast];
  [condition unlock];
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
  NSEnumerator *ifEnum = nil;
  DKInterface *theIf = nil;
  [condition lock];
  while (CACHE_BUILT != state)
  {
    [condition wait];
  }
  [tableLock lock];
  ifEnum = [interfaces objectEnumerator];
  while (nil != (theIf = [ifEnum nextObject]))
  {
    [self _installAllMethodsFromInterface: theIf];
  }
  [tableLock unlock];
  state = CACHE_READY;
  [condition broadcast];
  [condition unlock];

}
- (void)_setupTables
{
  if ((NULL == selectorToMethodMap)
    || (nil == interfaces)
    || (nil == children))
  {
    if (NO_TABLES == state)
    {
      [condition lock];
      if (NO_TABLES != state)
      {
	[condition unlock];
        return;
      }
      else
      {
	[tableLock lock];
      }
      if (NULL == selectorToMethodMap)
      {
	selectorToMethodMap = NSCreateMapTable(NSIntMapKeyCallBacks,
	  NSObjectMapValueCallBacks,
	  10);
      }
      if (nil == interfaces)
      {
	interfaces = [NSMutableDictionary new];
      }
      if (nil == children)
      {
	children = [NSMutableArray new];
      }
      [tableLock unlock];
      state = HAVE_TABLES;
      [condition broadcast];
      [condition unlock];
    }
  }
}

- (void)_addInterface: (DKInterface*)interface
{
  NSString *ifName = [interface name];
  if (nil != ifName)
  {
    // Only add named interfaces:
    [tableLock lock];
    [interfaces setObject: interface
                   forKey: ifName];
    // Check whether this is the interface we need to activate:
    if ([activeInterface isKindOfClass: [NSString class]])
    {
      if ([ifName isEqualToString: (NSString*)activeInterface])
      {
	ASSIGN(activeInterface, interface);
      }
    }
    [tableLock unlock];
  }
}

- (void)_addChildNode: (DKObjectPathNode*)node
{
  if (nil != node)
  {
    [tableLock lock];
    [children addObject: node];
    [tableLock unlock];
  }
}

- (void)_buildMethodCache
{
  DKIntrospectionParserDelegate *delegate = [[DKIntrospectionParserDelegate alloc] initWithParentForNodes: self];
  NSXMLParser *parser = nil;
  NSData *introspectionData = nil;


  [condition lock];
  while (WILL_BUILD_CACHE != state)
  {
    [condition wait];
  }
  state = BUILDING_CACHE;
  [condition unlock];

  // Get the introspection data:
  introspectionData = [[self Introspect] dataUsingEncoding: NSUTF8StringEncoding];

  [condition lock];

  if (BUILDING_CACHE == state)
  {
    // Set up parser and delegate:
    parser = [[NSXMLParser alloc] initWithData: introspectionData];
    [parser setDelegate: delegate];

    // Generate the introspection tree:
    [parser parse];

    state = CACHE_BUILT;
    [condition broadcast];
  }

  if (CACHE_BUILT == state)
  {
    [condition unlock];
    [self _installAllMethods];
  }
  else
  {
    [condition unlock];
  }

  // Cleanup
  [parser release];
  [delegate release];
}

- (void) dealloc
{
  [endpoint release];
  [service release];
  [path release];
  [interfaces release];
  [children release];
  [activeInterface release];
  NSFreeMapTable(selectorToMethodMap);
  [tableLock release];
  [condition release];
  [super dealloc];
}

@end

#if HAVE_TOYDISPATCH == 1
static void DKInitIntrospectionThread(void *data)
{
  /*
   * Make GNUstep aware of the fact that we are using a thread that it doesn't
   * yet know about:
   */
  GSRegisterCurrentThread();
}
#endif

static inline void DKBuildMethodCacheForProxy(void *p)
{
  /*
   * Set up an autorelease pool since we will create quite a few autoreleased
   * objects on the way. Also, if we are executed in a new thread, we strictly
   * need to create the pool ourselves.
   */
  NSAutoreleasePool *arp = [[NSAutoreleasePool alloc] init];
  [(DKProxy*)p _buildMethodCache];
  [arp release];

  /*
   * In asynchronous mode, we did retain the proxy before triggering cache
   * generation to keep it from going away while in use. Hence, we need to
   * release it here.
   */
  IF_ASYNC([(DKProxy*)p release]);
}
