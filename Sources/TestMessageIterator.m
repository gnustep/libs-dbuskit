#import <DBUSMessageIterator.h>
#import <DBUSMessageCall.h>
#import <Foundation/NSDebug.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <UnitKit/UnitKit.h>

#include <limits.h>

@interface DBUSMessageIterator (Tests) <UKTest>
@end

@implementation DBUSMessageIterator (Tests)

- (id) initForTest
{
  DBUSMessageCall *aMsg;

  //All message types share the same code for the iterator (it doesn't matter
  //that this is a MessageCall or an Error, etc.)
  aMsg = [[DBUSMessageCall alloc] initMessageCallWithName: NULL
                                                     path: @"/a/path"
                                                interface: NULL
                                                 selector: @selector(aSel)];
  [self initWithMessage: aMsg];

  [super init];

  return self;
}

- (void) testEmpty
{
  [self readIteratorInit];
  UKFalse([self readBool]);
  UKFalse([self readByte]);
}

- (void) testBool
{
  [self appendIteratorInit];
  [self appendBool: YES];
  [self appendBool: NO];

  [self readIteratorInit];
  UKStringsEqual(@"b", [self description]);
  UKTrue([self readBool]);
  UKStringsEqual(@"b", [self description]);
  UKFalse([self readBool]);
}

- (void) testByte
{
  unsigned char b1, b2;
  b1 = (unsigned char) 1;
  b2 = (unsigned char) 2;

  [self appendIteratorInit];
  [self appendByte: b1];
  [self appendByte: b2];

  [self readIteratorInit];
  UKStringsEqual(@"y", [self description]);
  UKIntsEqual((int)b1, (int)[self readByte]);
  UKStringsEqual(@"y", [self description]);
  UKIntsEqual((int)b2, (int)[self readByte]);
}

- (void) compareStringsInDictionary: (NSDictionary *)source
     withStringsInAnotherDictionary: (NSDictionary *)dest
{
  NSArray *keys;
  int i, count;
  id key, sourceValue, destValue;

  keys = [source allKeys];
  count = [keys count];
  for (i = 0; i < count; i++)
  {
    key = [keys objectAtIndex: i];
    sourceValue = [source objectForKey: key];
    UKNotNil(destValue = [dest objectForKey: key]);
    UKStringsEqual(sourceValue, destValue);
  }
}

- (void) testNSDictionary
{
  NSDictionary *source, *dest;

  source = [NSDictionary dictionaryWithObject: @"hoho"
                                       forKey: @"haha"];

  [self appendIteratorInit];
  [self appendDictionary: source];

  dest = [self readDictionary];

  [self compareStringsInDictionary: source
    withStringsInAnotherDictionary: dest];
}

- (void) testString
{
  NSString *str1, *str2;

  str1 = [NSString stringWithString: @"Test1"];
  str2 = [NSString stringWithString: @"Test2"];

  [self appendIteratorInit];
  [self appendString: str1];
  [self appendString: str2];

  [self readIteratorInit];
  UKStringsEqual(@"s", [self description]);
  UKStringsEqual(str1, [self readString]);
  UKStringsEqual(@"s", [self description]);
  UKStringsEqual(str2, [self readString]);
}

- (void) testUInt32
{
  unsigned int int1, int2;

  int1 = UINT_MAX;
  int2 = 0;

  [self appendIteratorInit];
  [self appendUInt32: int1];
  [self appendUInt32: int2];

  [self readIteratorInit];
  UKStringsEqual(@"u", [self description]);
  UKIntsEqual(int1, [self readUInt32]);
  UKStringsEqual(@"u", [self description]);
  UKIntsEqual(int2, [self readUInt32]);
}

@end
