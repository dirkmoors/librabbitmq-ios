//
//  AMQPConnection.m
//  This file is part of librabbitmq-objc.
//  Copyright (C) 2014 *Prof. MAAD* aka Max Wolter
//  librabbitmq-objc is released under the terms of the GNU Lesser General Public License Version 3.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU Lesser General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU Lesser General Public License for more details.
//  
//  You should have received a copy of the GNU Lesser General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

#import "AMQPConnection.h"

# import "rabbitmq-c/amqp.h"
# import "rabbitmq-c/amqp_ssl_socket.h"
# import "rabbitmq-c/amqp_framing.h"
# import <unistd.h>

# import "AMQPChannel.h"

// Reference: https://github.com/alanxz/rabbitmq-c/blob/master/examples/amqps_exchange_declare.c

@implementation AMQPConnection

@synthesize internalConnection = connection;

- (id)init
{
	if(self = [super init])
	{
		connection = amqp_new_connection();
		nextChannel = 1;
	}
	
	return self;
}
- (void)dealloc
{
	[self disconnect];
	
	amqp_destroy_connection(connection);
	
	[super dealloc];
}

- (void)connectToHost:(NSString*)host onPort:(int)port
{
    int status;
    
    socketFD = amqp_ssl_socket_new(connection);
    if (!socketFD) {
        NSLog(@"Error while creating SSL/TLS socket");
    }
    
#if 0
    /* TODO/FIXME - in case we need this */
    if (argc > 5) {
        status = amqp_ssl_socket_set_cacert(socket, argv[5]);
        if (status) {
            NSLog("Error setting CA certificate");
        }
    }
    
    if (argc > 7) {
        status = amqp_ssl_socket_set_key(socket, argv[7], argv[6]);
        if (status) {
            NSLog("Error setting client key/cert");
        }
    }
#endif

    const char *t = [host cStringUsingEncoding:NSUTF8StringEncoding];
    status = amqp_socket_open(socketFD, t, port);
    if (status) {
        NSLog(@"Error opening SSL/TLS connection");
    }
}

- (void)loginAsUser:(NSString*)username withPasswort:(NSString*)password onVHost:(NSString*)vhost
{
	amqp_rpc_reply_t reply = amqp_login(connection, [vhost UTF8String], 0, 131072, 0, AMQP_SASL_METHOD_PLAIN, [username UTF8String], [password UTF8String]);
	
	if(reply.reply_type != AMQP_RESPONSE_NORMAL)
	{
		[NSException raise:@"AMQPLoginException" format:@"Failed to login to server as user %@ on vhost %@ using password %@: %@", username, vhost, password, [self errorDescriptionForReply:reply]];
	}
}
- (void)disconnect
{
	amqp_rpc_reply_t reply = amqp_connection_close(connection, AMQP_REPLY_SUCCESS);
	
	if(reply.reply_type != AMQP_RESPONSE_NORMAL)
	{
		[NSException raise:@"AMQPConnectionException" format:@"Unable to disconnect from host: %@", [self errorDescriptionForReply:reply]];
	}
}

- (void)checkLastOperation:(NSString*)context
{
	amqp_rpc_reply_t reply = amqp_get_rpc_reply(connection);
	
	if(reply.reply_type != AMQP_RESPONSE_NORMAL)
	{
		[NSException raise:@"AMQPException" format:@"%@: %@", context, [self errorDescriptionForReply:reply]];
	}
}

- (AMQPChannel*)openChannel
{
	AMQPChannel *channel = [[AMQPChannel alloc] init];
	[channel openChannel:nextChannel onConnection:self];
	
	nextChannel++;

	return [channel autorelease];
}

@end
