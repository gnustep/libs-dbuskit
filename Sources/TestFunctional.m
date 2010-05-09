#import <DBUSConnection.h>
#import <DBUSMessage.h>
#import <DBUSServer.h>

#import <Foundation/NSException.h>
#import <Foundation/NSObject.h>
#import <UnitKit/UnitKit.h>

@interface TestFunctional : NSObject <UKTest>
@end

@implementation TestFunctional

//- (void) testClient
//{
  //DBUSConnection *conn;
  //id obj;

  //conn = [[DBUSConnection alloc] initWithSessionBus];
  //AUTORELEASE(conn);
  //obj = [conn objectWithName: @"org.freedesktop.DBus"
                        //path: @"/"
                   //interface: @"org.freedesktop.DBus"];

  //AUTORELEASE(obj);

  //NS_DURING
    //{
      //NSLog(@"GetId: %d", [obj GetId]);
      //NSLog(@"%d", [obj Hello]);
    //}
  //NS_HANDLER
    //{
      //NSLog(@"Exception raised: %@, reason: %@", [localException name],
            //[localException reason]);
    //}
  //NS_ENDHANDLER
//}

void print_message_signature(DBusMessage *msg)
{
  DBUSMessage *aMsg;

  aMsg = [[DBUSMessage alloc] initWithMessage: msg];
  NSLog(@"message signature: %@", aMsg);
  RELEASE(aMsg);
}

- (void) testServer
{
  DBUSConnection *serverConn, *clientConn;
  DBUSServer *server;
  id obj;

  serverConn = [DBUSConnection connectionWithSessionBus];

  server = [DBUSServer serverWithConnection: serverConn
                                       name: @"org.foo.test"];

  [server registerCallback: print_message_signature
             forObjectPath: @"/bar"];

  /*
  clientConn = [DBUSConnection connectionWithSessionBus];
  obj = [clientConn objectWithName: @"org.foo.test"
                        path: @"/bar"
                   interface: @""];

  UKTrue([[server connection] isConnected]);
  */

  //[[NSRunLoop currentRunLoop] run];

  while (1)
    {
      sleep(1);
    }
}

@end
