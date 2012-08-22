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
#import <Foundation/NSUserDefaults.h>
#import <Foundation/NSXMLNode.h>
#import <Foundation/NSXMLParser.h>

#import <GNUstepBase/NSDebug+GNUstepBase.h>

#define INCLUDE_RUNTIME_H
#include "config.h"
#undef INCLUDE_RUNTIME_H

#import "DBusKit/DKNotificationCenter.h"

#import "DKMethod.h"
#import "DKProperty.h"
#import "DKPropertyMethod.h"
#import "DKSignal.h"
#import "DKInterface.h"
#import "DKEndpoint.h"
#import "DKProxy+Private.h"

@implementation DKInterface


+ (id)interfaceForObjCClassOrProtocol: (void*)entity
                              isClass: (BOOL)isClass
{
  Protocol *theProto = NULL;
  Class theClass = nil;
  if (NULL == entity)
  {
    return nil;
  }
  else if (isClass)
  {
    theClass = (Class)entity;
  }
  else
  {
    theProto = (Protocol*)entity;
  }

  NSString *typeComponent = nil;
  const char *identifier = NULL;
  if (isClass)
  {
    typeComponent = @"class";
    identifier = class_getName(theClass);
  }
  else
  {
    typeComponent = @"protocol";
    identifier = protocol_getName(theProto);
  }
  NSString *ifName = [NSString stringWithFormat: @"org.gnustep.objc.%@.%s",
   typeComponent, identifier];
  DKInterface *theIf = [[[DKInterface alloc] initWithName: ifName
                                                  parent: nil] autorelease];
  unsigned int methodCount = 0;
  Method *cMethodList = NULL;
  struct objc_method_description *pMethodList = NULL;

  if (isClass)
  {
    cMethodList = class_copyMethodList(theClass, &methodCount);
  }
  else
  {
    // Copy only required instance methods
    pMethodList = protocol_copyMethodDescriptionList(theProto, YES, YES, &methodCount);
  }

  // Don't bother exporting empty interfaces
  // TODO: Amend once we handle properties.
  if (0 == methodCount)
  {
    // don't free anything
    return nil;
  }

  // Get the array of additional permitted messages:
  NSArray *messages = [[NSUserDefaults standardUserDefaults] arrayForKey:
    @"GSPermittedMessages"];

  // Iterate over the methods an generate DKMethods for them:
  for (int i = 0; i < methodCount; i++)
  {
    SEL selector = 0;
    NSString *selName = nil;

    if (isClass)
    {
      selector = method_getName(cMethodList[i]);
    }
    else
    {
      selector = pMethodList[i].name;
    }
    selName = [NSString stringWithUTF8String: sel_getName(selector)];

    /*
     * Check whether we want to permit exporting this method, the checks
     * correspond to those in gnustep-gui's GSServicesManager. (the
     * userData:error: methods are not useful yet, though. They have an out
     * parameter and require special-casing.
     */
    if (([selName hasPrefix: @"application:"] == YES)
      || ([selName hasSuffix: @":userData:error:"] == YES)
      || ([messages containsObject: selName]))
    {
      DKMethod *theMethod = nil;
      if (isClass)
      {
        theMethod = [DKMethod methodWithObjCMethod: cMethodList[i]];
      }
      else
      {
	theMethod = [DKMethod methodWithObjCMethodDescription: pMethodList[i]];
      }
      if (nil != theMethod)
      {
	[theIf addMethod: theMethod];
      }
    }
  }

  if (NULL != cMethodList)
  {
    free(cMethodList);
  }
  if (NULL != pMethodList)
  {
    free(pMethodList);
  }

  //TODO: Enumerate properties

  if (0 == [[theIf methods] count])
  {
    return nil;
  }
  return theIf;
}

+ (id)interfaceForObjCClass: (Class)theClass
{
  return [self interfaceForObjCClassOrProtocol: (void*)theClass
                                       isClass: YES];
}
+ (id)interfaceForObjCProtocol: (Protocol*)theProto
{
  return [self interfaceForObjCClassOrProtocol: (void*)theProto
                                       isClass: NO];
}


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
  [self _addMember: property
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

  if ((nil == [methods objectForKey: [method name]])
    && (NO == [method isKindOfClass: [DKPropertyMethod class]]))
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

- (void)installProperties
{
  NSEnumerator *propertyEnum = [properties objectEnumerator];
  DKProperty *property = nil;
  SEL installationSelector = @selector(installMethod:);
  IMP installMethod = [self methodForSelector: installationSelector];
  while (nil != (property = [propertyEnum nextObject]))
  {
    DKPropertyAccessor *accessor = [property accessorMethod];
    DKPropertyMutator *mutator = [property mutatorMethod];
    BOOL accessorExists = (nil != [self DBusMethodForSelector: NSSelectorFromString([accessor selectorString])]);
    BOOL mutatorExists = (nil != [self DBusMethodForSelector: NSSelectorFromString([mutator selectorString])]);
    if ((nil != accessor) && (NO == accessorExists))
    {
      installMethod(self, installationSelector, accessor);
    }
    if ((nil != mutator) && (NO == mutatorExists))
    {
      installMethod(self, installationSelector, mutator);
    }
  }
}

- (void)registerSignalsWithNotificationCenter: (DKNotificationCenter*)center
{
  NSEnumerator *signalEnum = [signals objectEnumerator];
  DKSignal *signal = nil;
  SEL registrationSelector = @selector(registerWithNotificationCenter:);
  IMP registerSignal = class_getMethodImplementation([DKSignal class],
    registrationSelector);
  while (nil != (signal = [signalEnum nextObject]))
  {
    registerSignal(signal, registrationSelector, center);
  }
}


- (void)registerSignals
{
  DKProxy *theProxy = [self proxyParent];
  DKNotificationCenter *theCenter = nil;
  if (nil == theProxy)
  {
    return;
  }
  theCenter = [DKNotificationCenter centerForBusType: [[theProxy _endpoint] DBusBusType]];
  [self registerSignalsWithNotificationCenter: theCenter];
}


- (DKMethod*) DBusMethodForSelector: (SEL)selector
                          normalize: (BOOL)doNormalize
{
  DKMethod *theMethod = nil;
  if (0 == selector)
  {
    return nil;
  }
  if (doNormalize)
  {
    selector = sel_getUid(sel_getName(selector));
    return NSMapGet(selectorToMethodMap, selector);
  }
  else
  {
    theMethod = NSMapGet(selectorToMethodMap, selector);
    if (nil == theMethod)
    {
      // Second chance, find a normalized method:
      return [self DBusMethodForSelector: selector
                               normalize: YES];
    }
  }
  return theMethod;
}

- (DKMethod*)DBusMethodForSelector: (SEL)selector
{
  return [self DBusMethodForSelector: selector
                           normalize: NO];
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

- (NSString*)protocolDeclarationForObjC2: (BOOL)useObjC2
{
  NSMutableString *declaration = [NSMutableString stringWithFormat: @"@protocol %@\n\n", [self protocolName]];
  NSEnumerator *methodEnum = [methods objectEnumerator];
  NSEnumerator *propertyEnum = [properties objectEnumerator];
  DKMethod *method = nil;
  DKProperty *property = nil;
  while (nil != (method = [methodEnum nextObject]))
  {
    [declaration appendFormat: @"%@\n\n", [method methodDeclaration]];
  }

  while (nil != (property = [propertyEnum nextObject]))
  {
    [declaration appendString: [property propertyDeclarationForObjC2: useObjC2]];
  }
  [declaration appendFormat: @"@end\n"];
  return declaration;
}

- (NSString*)protocolDeclaration
{
  return [self protocolDeclarationForObjC2: YES];
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

- (NSArray*)arrayOfXMLNodesFromIntrospectionNodesInDictionary: (NSDictionary*)dict
{
  NSEnumerator *theEnum = [dict objectEnumerator];
  NSMutableArray *array = [NSMutableArray arrayWithCapacity: [dict count]];
  DKIntrospectionNode *iNode = nil;
  while (nil != (iNode = [theEnum nextObject]))
  {
    NSXMLNode *n = [iNode XMLNode];
    if (nil != n)
    {
      [array addObject: n];
    }
  }
  return array;
}


- (NSXMLNode*)XMLNode
{
  NSXMLNode *nameAttribute = [NSXMLNode attributeWithName: @"name"
                                              stringValue: name];
  NSMutableArray *childNodes = [NSMutableArray array];
  if (0 < [properties count])
  {
    [childNodes addObjectsFromArray:
      [self arrayOfXMLNodesFromIntrospectionNodesInDictionary: properties]];

  }
  if (0 < [methods count])
  {
    [childNodes addObjectsFromArray:
      [self arrayOfXMLNodesFromIntrospectionNodesInDictionary: methods]];
  }
  if (0 < [signals count])
  {
    [childNodes addObjectsFromArray:
      [self arrayOfXMLNodesFromIntrospectionNodesInDictionary: signals]];
  }
  [childNodes addObjectsFromArray: [self annotationXMLNodes]];

  return [NSXMLNode elementWithName: @"interface"
                           children: childNodes
                         attributes: [NSArray arrayWithObject: nameAttribute]];
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
