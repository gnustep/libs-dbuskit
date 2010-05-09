/* -*-objc-*-
  Introspector for DBUS XML format
  Copyright (C) 2007 Free Software Foundation, Inc.

  Written by: Ricardo Correa <r.correa.r@gmail.com>
  Created: June 2008

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

#import "DBUSIntrospector.h"

#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSEnumerator.h>
#import <Foundation/NSException.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSMethodSignature.h>

#import <GNUstepBase/GSXML.h>

#include <dbus/dbus.h>

@interface DBUSIntrospector (Private)

- (NSInvocation *) _invWithName: (NSString *)name
                         ofType: (NSString *)aType
                    inInterface: (NSString *)anInterface;
- (NSMutableDictionary *) _validNodesInInterface: (GSXMLNode *)interfaceNode;
- (NSInvocation *) _invocationFromNode: (GSXMLNode *)node;
- (NSInvocation *) _invocationFromMethodOrSignal: (GSXMLNode *)node
                                     elementName: (NSString *)elmntName;
- (NSMethodSignature *) _signatureFromMethodOrSignalNode: (GSXMLNode *)node;

/**
 * Updates a dictionary with the contents of another dictionary, doing a
 * merge of both: if a key exists in both the source and destination
 * dictionaries then a merge is done, instead of a replacement.
 *
 * Destination dictionary must be mutable.
 */

static void _updateDictWithDict(NSMutableDictionary *oneDict,
                                NSDictionary *anotherDict);

@end

@implementation DBUSIntrospector

static NSString* dbusSignatureToObjC(NSString *sig)
{
  //TODO: find a way to test this
  NSString *s = nil;
  char type;

  type = [sig UTF8String][0];

  if (type)
    {
      switch (type)
        {
        case DBUS_TYPE_INVALID:
          break;
        case DBUS_TYPE_SIGNATURE:
          s =  [NSString stringWithFormat: @"%c", _C_SEL];
          break;
        case DBUS_TYPE_OBJECT_PATH:
          s =  [NSString stringWithFormat: @"%c", _C_ID];
          break;
        case DBUS_TYPE_STRING:
          s =  [NSString stringWithFormat: @"%c", _C_CHARPTR];
          break;
        case DBUS_TYPE_BOOLEAN:
          s =  [NSString stringWithFormat: @"%c", _C_UCHR];
          break;
        case DBUS_TYPE_BYTE:
          s =  [NSString stringWithFormat: @"%c", _C_CHR];
          break;
        case DBUS_TYPE_INT16:
          s =  [NSString stringWithFormat: @"%c", _C_SHT];
          break;
        case DBUS_TYPE_UINT16:
          s =  [NSString stringWithFormat: @"%c", _C_USHT];
          break;
        case DBUS_TYPE_INT32:
          s =  [NSString stringWithFormat: @"%c", _C_INT];
          break;
        case DBUS_TYPE_UINT32:
          s =  [NSString stringWithFormat: @"%c", _C_UINT];
          break;
        case DBUS_TYPE_INT64:
          s =  [NSString stringWithFormat: @"%c", _C_LNG];
          break;
        case DBUS_TYPE_UINT64:
          s =  [NSString stringWithFormat: @"%c", _C_ULNG];
          break;
        case DBUS_TYPE_DOUBLE:
          s =  [NSString stringWithFormat: @"%c", _C_DBL];
          break;
        case DBUS_TYPE_ARRAY:
          //s = _C_ARY_B;
          //let's return a NSArray instead
          s =  [NSString stringWithFormat: @"%c", _C_ID];
          break;
        case DBUS_TYPE_VARIANT:
          s =  [NSString stringWithFormat: @"%c", _C_UNION_B];
          break;
          //TODO: deal with this
        case DBUS_STRUCT_BEGIN_CHAR:
        case DBUS_STRUCT_END_CHAR:
        case DBUS_DICT_ENTRY_BEGIN_CHAR:
        case DBUS_DICT_ENTRY_END_CHAR:
          break;
        }
    }

  return s;
}

//not used yet
+ (NSString *) lowercaseFirstLetter: (NSString *) oldName
{
  NSString *ret = nil;
  if (oldName)
    {
      NSMutableString *newName = nil;
      newName = [NSMutableString string];
      [newName setString: [oldName substringFromIndex: 1]];
      [newName insertString: [[oldName substringToIndex: 1] lowercaseString]
                    atIndex: 0];
      ret = [NSString stringWithString: newName];
    }

  return ret;
}

//not used yet
+ (NSString *) uppercaseFirstLetter: (NSString *) oldName
{
  NSString *ret = nil;
  if (oldName)
    {
      NSMutableString *newName = nil;
      newName = [NSMutableString string];
      [newName setString: [oldName substringFromIndex: 1]];
      [newName insertString: [[oldName substringToIndex: 1] uppercaseString]
                    atIndex: 0];
      ret = [NSString stringWithString: newName];
    }

  return ret;
}

+ (id) introspectorWithData: (NSData *)theData
{
  return AUTORELEASE([[self alloc] initWithData: theData]);
}

+ (id) introspectorWithDBUSInfo: (GSXMLDocument *)dbusInfo
{
  return AUTORELEASE([[self alloc] initWithDBUSInfo: dbusInfo]);
}

- (id) initWithData: (NSData *)theData
{
  GSXMLParser *parser = nil;

  if (theData)
    {
      parser = [GSXMLParser parserWithData: theData];
      if ([parser parse])
        {
          return [self initWithDBUSInfo: [parser document]];
        }
      else
        {
          if (parser)
            {
              [NSException raise: NSParseErrorException
                          format: @"%@ parsing failed",
                NSStringFromSelector(_cmd)];
            }
          else
            {
              NSDebugLLog(@"DBUSIntrospector", @"parser creation failed");
            }
        }
    }
  else
    {
      NSDebugLLog(@"DBUSIntrospector", @"theData = %@", theData);
    }

  return nil;
}

- (id) initWithDBUSInfo: (GSXMLDocument *)dbusInfo
{
  GSXPathContext *aContext = nil;

  if (dbusInfo)
    {
      aContext = [[GSXPathContext alloc] initWithDocument: dbusInfo];
      if (aContext)
        {
          ASSIGN(context, aContext);
          interfaces = nil;

          [self init];
          return self;
        }
      else
        {
          NSDebugLLog(@"DBUSIntrospector", @"aContext = %@", aContext);
        }
    }
  else
    {
      NSDebugLLog(@"DBUSIntrospector", @"dbusInfo = %@", dbusInfo);
    }

  return nil;
}

- (void) dealloc
{
  [context dealloc];
  [interfaces dealloc];
  [super dealloc];
}

- (BOOL) buildMethodCache
{
  //TODO: simplify this
  GSXPathNodeSet *result = nil;
  NSMutableDictionary *interfacesDictionary;

  interfacesDictionary = [NSMutableDictionary dictionary];
  /*
     Get all the methods and signals that have an interface parent
     For each interface we traverse it's children and get an invocation
     */
  result = (GSXPathNodeSet *)[context evaluateExpression: @"//interface"];
  if ([result isKindOfClass:[GSXPathNodeSet class]])
    {
      NSMutableDictionary *interfaceWithInvocations = nil;
      int interfaceCount, ifaceIndex;
      interfaceCount = [result count];
      GSXMLNode *interfaceNode;
      for (ifaceIndex=0; ifaceIndex<interfaceCount; ifaceIndex++)
        {
          interfaceNode = [result nodeAtIndex: ifaceIndex];
          interfaceWithInvocations =
            [self _validNodesInInterface: interfaceNode];
          _updateDictWithDict(interfacesDictionary, interfaceWithInvocations);
        }
    }
  /*
     Get all the methods and signals that don't have an interface parent
     and get an invocation from each method or signal
     */
  result = (GSXPathNodeSet *)[context evaluateExpression:
    @"//node/method | //node/signal"];
  if ([result isKindOfClass:[GSXPathNodeSet class]])
    {
      int nodeCount, nodeIndex;
      GSXMLNode *node;
      NSInvocation *inv;
      NSMutableDictionary *methodsAndSignals;
      NSMutableDictionary *newNode;
      NSMutableDictionary *methods;
      NSMutableDictionary *signals;

      nodeCount = [result count];
      methods = [NSMutableDictionary dictionary];
      signals = [NSMutableDictionary dictionary];

      for (nodeIndex=0; nodeIndex<nodeCount; nodeIndex++)
        {
          node = [result nodeAtIndex: nodeIndex];
          inv = [self _invocationFromNode: node];
          if (inv)
            {
              if ([[node name] isEqualToString: @"method"])
                {
                  newNode = [NSMutableDictionary dictionaryWithObject:
                            [NSMutableDictionary dictionaryWithObject: inv
                                                        forKey: @""]
                                                        forKey:
                                NSStringFromSelector([inv selector])];
                  _updateDictWithDict(methods, newNode);
                }
              else if ([[node name] isEqualToString: @"signal"])
                {
                  newNode = [NSMutableDictionary dictionaryWithObject:
                            [NSMutableDictionary dictionaryWithObject: inv
                                                        forKey: @""]
                                                        forKey:
                                NSStringFromSelector([inv selector])];
                  _updateDictWithDict(signals, newNode);
                }
            }
        }
      methodsAndSignals = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        methods, @"methods", signals, @"signals", nil];
      _updateDictWithDict(interfacesDictionary, methodsAndSignals);
    }

  if (interfacesDictionary)
    {
      ASSIGN(interfaces, interfacesDictionary);
      //we don't need the context anymore, let's free some memory
      RELEASE(context);
      return YES;
    }
  return NO;
}

- (NSInvocation *) methodNamed: (NSString *)methName
{
  return [self methodNamed: methName
               inInterface: @""];
}

- (NSInvocation *) methodNamed: (NSString *)methName
                   inInterface: (NSString *)theInterface
{
  return [self _invWithName: methName
                     ofType: @"methods"
                inInterface: theInterface];
}

- (NSInvocation *) signalNamed: (NSString *)sigName
{
  NSInvocation *inv;

  inv = [self signalNamed: sigName
              inInterface: @""];

  return inv;
}

- (NSInvocation *) signalNamed: (NSString *)sigName
                   inInterface: (NSString *)anInterface
{
  NSInvocation *inv;

  inv = [self _invWithName: sigName
                    ofType: @"signals"
               inInterface: anInterface];

  return inv;
}

@end

@implementation DBUSIntrospector (Private)

- (NSInvocation *) _invWithName: (NSString *)name
                         ofType: (NSString *)aType
                    inInterface: (NSString *)theInterface
{
  NSDictionary *ifaces;
  NSInvocation *inv = nil;
  int ifacesCount;

  if (interfaces)
    {
      ifaces = [[interfaces objectForKey: aType]
                            objectForKey: name];
      ifacesCount = [ifaces count];

      if (ifacesCount == 0)
        {
          [NSException raise: @"DBUSProxyInvocationException"
                      format: @"No invocation found for %@", name];
        }
      else if (ifacesCount == 1)
        {
          inv = [[ifaces allValues] objectAtIndex: 0];
        }
      else if (![theInterface isEqualToString: @""])
        {
          inv = [[ifaces allValues] objectAtIndex: 0];
        }
      else
        {
          [NSException raise: @"DBUSProxyInvocationException"
                      format: @"More than one invocation found for %@", name];
        }
    }
  else
    {
      NSDebugLLog(@"DBUSIntrospector", @"Cache not built");
    }

  return inv;
}

- (NSMutableDictionary *) _validNodesInInterface: (GSXMLNode *)interfaceNode
{
  //TODO: eliminate duplication with buildMethodCache
  NSInvocation *inv = nil;
  NSMutableDictionary *methodsAndSignals;
  if (interfaceNode && [[interfaceNode name] isEqualToString: @"interface"])
    {
      NSMutableDictionary *ifaceAndInv;
      NSMutableDictionary *methods;
      NSMutableDictionary *signals;
      NSString *ifaceName;

      methods = [NSMutableDictionary dictionary];
      signals = [NSMutableDictionary dictionary];
      NSDebugLLog(@"DBUSIntrospector", @"got interface with name: %@",
          [interfaceNode objectForKey: @"name"]);
      GSXMLNode *node = [interfaceNode firstChildElement];
      while (node)
        {
          inv = [self _invocationFromNode: node];
          if (inv)
            {
              ifaceName = [interfaceNode objectForKey: @"name"];
              if ([[node name] isEqualToString: @"method"])
                {
                  ifaceAndInv = [NSMutableDictionary dictionaryWithObject: inv
                                                            forKey: ifaceName];
                  [methods setObject: ifaceAndInv
                              forKey: NSStringFromSelector([inv selector])];
                }
              else if ([[node name] isEqualToString: @"signal"])
                {
                  ifaceAndInv = [NSMutableDictionary dictionaryWithObject: inv
                                                            forKey: ifaceName];
                  [signals setObject: ifaceAndInv
                              forKey: NSStringFromSelector([inv selector])];
                }
            }
          node = [node nextElement];
        }
      methodsAndSignals = [NSMutableDictionary dictionaryWithObjectsAndKeys:
        methods, @"methods", signals, @"signals", nil];
      NSDebugLLog(@"DBUSIntrospector", @"done with interface: %@",
                                 [interfaceNode objectForKey: @"name"]);
    }
  else
    {
      NSDebugLLog(@"DBUSIntrospector", @"%@ not an interface",
                  [interfaceNode name]);
    }
  return methodsAndSignals;
}

- (NSInvocation *) _invocationFromNode: (GSXMLNode *)node
{
  NSInvocation *inv = nil;

  //we have a node and it's a method
  if ([node isElement] && [[node name] isEqualToString: @"method"])
    {
      inv = [self _invocationFromMethodOrSignal: node
                                       elementName: @"method"];
    }
  //we have a node and it's a signal
  else if ([node isElement] && [[node name] isEqualToString: @"signal"])
    {
      inv = [self _invocationFromMethodOrSignal: node
                                       elementName: @"signal"];
    }
  else
    {
      if (!node)
        {
          NSDebugLLog(@"DBUSIntrospector", @"node = %@", node);
        }
      else if (![node isElement])
        {
          NSDebugLLog(@"DBUSIntrospector", @"node is not an element");
        }
      else
        {
          NSDebugLLog(@"DBUSIntrospector", @"node is %s", [node objectForKey: @"name"]);
        }
    }
  return inv;
}

- (NSInvocation *) _invocationFromMethodOrSignal: (GSXMLNode *)node
                                     elementName: (NSString *)elmntName
{
  NSInvocation *inv = nil;
  NSMethodSignature *sig = nil;

  NSDebugLLog(@"DBUSIntrospector",
              @"%@ name %@", elmntName, [node objectForKey: @"name"]);
  if (node)
    {
      sig = [self _signatureFromMethodOrSignalNode: node];
      if (sig)
        {
          inv = [NSInvocation invocationWithMethodSignature: sig];
          unsigned int numArgs = [sig numberOfArguments];
          //remove self and _cmd from the method count
          numArgs = numArgs - 2;
          NSMutableString *selName = [NSMutableString string];
          [selName setString: [node objectForKey: @"name"]];
          if (selName && ![selName isEqualToString: @""])
            {
              //add the colons at end of the string
              for (; numArgs>0; numArgs--)
                {
                  [selName appendString: @":"];
                }
              //we have the selector name with colons, let's build one
              SEL mySelector;
              /*
                 mySelector = NSSelectorFromString(
                 [NSString stringWithString: selName]);
                 NSSelectorFromString not working
                 Let's try with GSSelectorFromNameAndtypes
                 */
              mySelector = GSSelectorFromNameAndTypes([selName UTF8String],
                                                      [sig methodType]);
              if (mySelector == 0)
                {
                  inv = nil;
                }
              else
                {
                  [inv setSelector: mySelector];
                }
            }
          else
            {
              inv = nil;
            }
        }
      NSDebugLLog(@"DBUSIntrospector",
                  @"built invocation with name: \"%@\" and args: %s",
            NSStringFromSelector([inv selector]),
            [[inv methodSignature] methodType]);
    }

  return inv;
}

- (NSMethodSignature *) _signatureFromMethodOrSignalNode: (GSXMLNode *)node
{
  NSMethodSignature *sig = nil;
  NSString *objc_type, *direction;
  NSMutableString *sig_string;
  GSXMLNode *arg;
  BOOL retArgSet = NO;

  if (node)
    {
      arg = [node firstChildElement];
      sig_string = [NSMutableString stringWithCString: "@:"];
      while (arg)
        {
          NSDebugLLog(@"DBUSIntrospector", @"dbus type: %@, direction: %@",
              [arg objectForKey: @"type"], [arg objectForKey: @"direction"]);
          objc_type = dbusSignatureToObjC([arg objectForKey: @"type"]);
          direction = [arg objectForKey: @"direction"];
          //an argument without direction is out by default
          if ([direction isEqualToString: @"in"] || !direction)
            {
              [sig_string appendString: objc_type];
            }
          else
            {
              //only one out argument is allowed
              if (retArgSet)
                {
                  NSDebugLLog(@"DBUSIntrospector",
                              @"More than one out arg set. Stopping");
                  sig_string = nil;
                  retArgSet = YES;
                  break;
                }
              [sig_string insertString: objc_type atIndex: 0];
              //now we know we have an out argument
              retArgSet = YES;
            }
          arg = [arg nextElement];
        }
      //parsed all the arguments and no out arg has been found
      //let's set the return as void
      if (!retArgSet)
        {
          [sig_string insertString: [NSString stringWithFormat: @"%c", _C_VOID]
                           atIndex: 0];
        }
      if (sig_string)
        {
          sig = [NSMethodSignature signatureWithObjCTypes:
            [sig_string UTF8String]];
          [sig_string release];
        }
    }

  return sig;
}

static void _updateDictWithDict(NSMutableDictionary *dict,
                                NSDictionary *anotherDict)
{
  NSEnumerator *keys;
  id key, value, anotherValue;

  keys = [anotherDict keyEnumerator];

  if ([dict isKindOfClass: [NSMutableDictionary class]])
    {
      while ((key = [keys nextObject]))
        {
          value = [dict objectForKey: key];
          anotherValue = [anotherDict objectForKey: key];
          if (nil == value)
            {
              [dict setObject: anotherValue forKey: key];
            }
          else
            {
              if ([value isKindOfClass: [NSMutableDictionary class]])
                {
                  //if we have two dicts we merge
                  if ([anotherValue isKindOfClass: [NSDictionary class]])
                    {
                      _updateDictWithDict(value, anotherValue);
                    }
                  //if source isn't dict we just add to target
                  else
                    {
                      [value setObject: anotherValue
                                forKey: key];
                    }
                }
              //if target isn't a dict we overwrite the contents
              else
                {
                  [dict setObject: anotherValue forKey: key];
                }
            }
        }
    }
}

- (NSDictionary *) interfaces
{
  return interfaces;
}

@end
