/** Implementation of the DKInterface class encapsulating D-Bus interface information.
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
   */

#import <Foundation/NSDictionary.h>
#import <Foundation/NSMapTable.h>
#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSString.h>
#import <Foundation/NSXMLParser.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#import "DKMethod.h"
#import "DKSignal.h"
#import "DKInterface.h"


@implementation DKInterface
/**
 * Initializes the interface. Since interfaces need to be named, returns
 * <code>nil</code> when <var>aName</var> is <code>nil</code> or an empty
 * string.
 */
- (id) initWithName: (NSString*)aName
             parent: (id)aParent
{
  if (nil == (self = [super initWithName: aName
                                  parent: aParent]))
  {
    return nil;
  }

  if (0 == [aName length])
  {
    [self release];
    return nil;
  }

  methods = [NSMutableDictionary new];
  properties = [NSMutableDictionary new];
  signals = [NSMutableDictionary new];
  selectorToMethodMap = NSCreateMapTable(NSIntMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    10);
  return self;
}

- (NSDictionary*)methods
{
  return [[methods copy] autorelease];
}

- (NSDictionary*)signals
{
  return [[signals copy] autorelease];
}

- (NSDictionary*)properties
{
  return [[properties copy] autorelease];
}

- (void) _addMember: (DKIntrospectionNode*)node
             toDict: (NSMutableDictionary*)dict
{
  NSString *nodeName = [node name];
  if (0 != [nodeName length])
  {
    if (nil != [dict objectForKey: name])
    {
      NSWarnMLog(@"Not adding duplicate '%@' to interface '%@'.",
        nodeName, name);
      return;
    }
    [dict setObject: node
             forKey: nodeName];
  }
}

/**
 * Adds a method to the interface.
 */
- (void)addMethod: (DKMethod*)method
{
  [self _addMember: method
            toDict: methods];
}

/**
 * Adds a signal to the interface.
 */
- (void)addSignal: (DKSignal*)signal
{
  [self _addMember: signal
            toDict: signals];
}

- (void)addProperty: (DKProperty*)property
{
  //FIXME: Remove cast once a DKProperty class is there
  [self _addMember: (id)property
            toDict: properties];
}

/**
 * Removes the signal specified. Needed by DKNotificationCenter to replace stub
 * signals with the real introspected specification.
 */
- (void)removeSignalNamed: (NSString*)signalName
{
  if (nil != signalName)
  {
    [signals removeObjectForKey: signalName];
  }
}

- (void) installMethod: (DKMethod*)method
           forSelector: (SEL)selector
{
  selector = sel_getUid(sel_getName(selector));
  if ((method == nil) || (0 == selector))
  {
    return;
  }

  if (nil == [methods objectForKey: [method name]])
  {
    [self addMethod: method];
  }
  if (NULL != NSMapInsertIfAbsent(selectorToMethodMap, selector, method))
  {
    NSWarnMLog(@"Overloading selector '%@' for method '%@' in interface '%@' not supported",
      NSStringFromSelector(selector),
      [method name],
      name);
  }
}

/** Installs the method with its default selector. */
- (void)installMethod: (DKMethod*)aMethod
{
  const char* selectorString = [[aMethod selectorString] UTF8String];
  SEL untypedSelector = 0;

  if (NULL == selectorString)
  {
    NSWarnMLog(@"Cannot register selector with empty name for method %@");
    return;
  }

  untypedSelector = sel_registerName(selectorString);
  [self installMethod: aMethod
          forSelector: untypedSelector];
  NSDebugMLog(@"Registered %s as %p.",
    selectorString,
    untypedSelector);
}

- (void)installMethods
{
  NSEnumerator *methodEnum = [methods objectEnumerator];
  DKMethod *method = nil;
  SEL installationSelector = @selector(installMethod:);
  IMP installMethod = [self methodForSelector: installationSelector];
  while (nil != (method = [methodEnum nextObject]))
  {
    installMethod(self, installationSelector, method);
  }
}

- (void)registerSignals
{
  NSEnumerator *signalEnum = [signals objectEnumerator];
  DKSignal *signal = nil;
  SEL registrationSelector = @selector(registerWithNotificationCenter);
  IMP registerSignal = class_getMethodImplementation([DKSignal class],
    registrationSelector);
  while (nil != (signal = [signalEnum nextObject]))
  {
    registerSignal(signal, registrationSelector);
  }
}

- (DKMethod*) DBusMethodForSelector: (SEL)selector
{
  selector = sel_getUid(sel_getName(selector));
  return NSMapGet(selectorToMethodMap, selector);
}

- (NSString*)mangledName
{
  return [name stringByReplacingOccurrencesOfString: @"." withString: @"_"];
}

- (NSString*)protocolName
{
  NSString *protocolName = [annotations objectForKey: @"org.gnustep.objc.protocol"];
  if (nil == protocolName)
  {
    protocolName = [self mangledName];
  }
  return protocolName;
}

- (NSString*)protocolDeclaration
{
  NSMutableString *declaration = [NSMutableString stringWithFormat: @"@protocol %@\n\n", [self protocolName]];
  NSEnumerator *methodEnum = [methods objectEnumerator];
  DKMethod *method = nil;

  while (nil != (method = [methodEnum nextObject]))
  {
    [declaration appendFormat: @"%@\n\n", [method methodDeclaration]];
  }

  [declaration appendFormat: @"@end"];
  return declaration;
}

- (Protocol*)protocol
{
  return NSProtocolFromString([self protocolName]);
}

- (void)setMethods: (NSMutableDictionary*)newMethods
{
  ASSIGN(methods,newMethods);
  [[methods allValues] makeObjectsPerformSelector: @selector(setParent:)
                                       withObject: self];
}

- (void)setSignals: (NSMutableDictionary*)newSignals
{
  ASSIGN(signals,newSignals);
  [[signals allValues] makeObjectsPerformSelector: @selector(setParent:)
                                       withObject: self];
}

- (void)setProperties: (NSMutableDictionary*)newProperties
{
  ASSIGN(properties,newProperties);
  [[properties allValues] makeObjectsPerformSelector: @selector(setParent:)
                                          withObject: self];
}

/**
 * Regenerate the map table from another one, e.g. when copying the object.
 */
- (void)regenerateSelectorMethodMapWithMap: (NSMapTable*)sourceMap
                                   andZone: (NSZone*)zone
{
  /*
   * Keep a reference to the old map, just in case somebody is actually making
   * us regenerate our own mappings.
   */
  NSMapTable *oldMap = selectorToMethodMap;

  /* Setup enumerator and associated variables. */
  NSMapEnumerator theEnum = NSEnumerateMapTable(sourceMap);
  SEL thisSel = 0;
  DKMethod *thisMethod = nil;

  if (NULL == zone)
  {
    zone = NSDefaultMallocZone();
  }

  /*
   * Create a new map table, setting the capacity to the one we know from the
   * sourceMap.
   */
  selectorToMethodMap = NSCreateMapTableWithZone(NSIntMapKeyCallBacks,
    NSObjectMapValueCallBacks,
    NSCountMapTable(sourceMap),
    zone);

  /*
   * Enumerate the source map and add selector-method pairs with the matching
   * methods from our own method table.
   */
  while (NSNextMapEnumeratorPair(&theEnum, (void**)&thisSel, (void**)&thisMethod))
  {
    DKMethod *newMethod = [methods objectForKey: [thisMethod name]];
    if (newMethod)
    {
      NSMapInsert(selectorToMethodMap, (void*)thisSel, (void*)newMethod);
    }
  }
  NSEndMapTableEnumeration(&theEnum);

  /* Free the old map table, if any. */
  if (NULL != oldMap)
  {
    NSFreeMapTable(oldMap);
  }
}

- (id)copyWithZone: (NSZone*)zone
{
  DKInterface *newNode = [super copyWithZone: zone];
  NSMutableDictionary *newMethods = nil;
  NSMutableDictionary *newSignals = nil;
  NSMutableDictionary *newProperties = nil;
  newMethods = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: methods
                                                                   copyItems: YES];
  newSignals = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: signals
                                                                   copyItems: YES];
  newProperties = [[NSMutableDictionary allocWithZone: zone] initWithDictionary: properties
                                                                      copyItems: YES];
  [newNode setMethods: newMethods];
  [newNode regenerateSelectorMethodMapWithMap: selectorToMethodMap
                                      andZone: zone];
  [newNode setSignals: newSignals];
  [newNode setProperties: newProperties];
  [newMethods release];
  [newSignals release];
  [newProperties release];
  return newNode;
}

- (void)dealloc
{
  [methods release];
  [signals release];
  [properties release];
  NSFreeMapTable(selectorToMethodMap);
  [super dealloc];
}
@end
