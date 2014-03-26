//
//  AppDelegate.m
//  librabbitmq-ios
//
//  Created by Squarepusher on 03/03/14.
//  Copyright (c) 2014 Squarepusher. All rights reserved.
//

#import "AppDelegate.h"
#import "AMQPConnection.h"
#import "AMQPConsumer.h"
#import "AMQPChannel.h"
#import "AMQPMessage.h"
#import "AMQPExchange.h"
#import "AMQPQueue.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    //////////////////
    //BEGINNING OF AMQP DEMO CODE
    //TODO - Move outside of didFinishLaunchingWithOptions
    //into proper main() function
    
    // A flag modified when a signal is received
    __block Boolean acceptMessages = true;
    
    // GCD dispatch source
    // SIGINT = ^C
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGINT, 0, dispatch_get_global_queue(0, 0));
    
    // Set a code block (^{}) to be executed when a signal arrives
    dispatch_source_set_event_handler(source, ^{
        NSLog(@"Received signal SIGINT, going to quit after next message");
        acceptMessages = false;
    });
    dispatch_resume(source);
    
    // sigaction has to be told to ignore the signal processed with GCD
    {
        struct sigaction action = { 0 };
        action.sa_handler = SIG_IGN;
        sigaction(SIGINT, &action, NULL);
    }
    
    NSLog(@"Starting an AMQP RPC server");
    
    NSString* host = @"service.vrijhof.com";
    NSString* routingkey = @"routing key test"; // TODO/FIXME - what to fill in here?
    int port = 5673;
    NSString* user = @"joris";
    NSString* password = @"jorispw";
    NSString* vhost = @"joris_test_vhost";
    (void)user;
    (void)password;
    (void)vhost;
    
    AMQPConnection* connection = [[AMQPConnection alloc] init];
    
    [connection connectToHost:host onPort:port];
    [connection loginAsUser:host withPasswort:password onVHost:vhost];
    
    AMQPChannel* channel = [connection openChannel];
    
    AMQPQueue* queue = [[AMQPQueue alloc] initWithName:routingkey onChannel:channel isPassive:FALSE isExclusive:FALSE isDurable:FALSE getsAutoDeleted:TRUE];
    
	AMQPConsumer *consumer = [[AMQPConsumer alloc] initForQueue:queue onChannel:channel useAcknowledgements:TRUE isExclusive:TRUE receiveLocalMessages:NO];
    
    while (acceptMessages) {
        NSLog(@"Waiting for a message");
        
        AMQPMessage* message = [consumer pop];
        
        NSLog(@"message = %@", message);
        NSLog(@"message.body = %@", message.body);
        
        //
        // make a reply
        //
        
        AMQPChannel* replyChannel = [connection openChannel];
        
        AMQPExchange *exchange = [[AMQPExchange alloc] initDirectExchangeWithName:@"" onChannel:replyChannel isPassive:NO isDurable:NO getsAutoDeleted:YES];
        
        amqp_basic_properties_t props;
        props._flags = AMQP_BASIC_CONTENT_TYPE_FLAG | AMQP_BASIC_DELIVERY_MODE_FLAG;
        props.content_type = amqp_cstring_bytes("text/plain");
        //props.delivery_mode = AMQP_PERSISTENT_DELIVERY_MODE;
        
        if (message.correlationID) {
            props._flags |= AMQP_BASIC_CORRELATION_ID_FLAG;
            props.correlation_id = amqp_cstring_bytes([message.correlationID UTF8String]);
        }
        
        [exchange publishMessage:@"a simple reply message" usingRoutingKey:message.replyToQueueName];
    }
    
    NSLog(@"Closing an AMQP RPC server");
    
    // END OF AMQP DEMO ENGINE
    ////////////////////
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
