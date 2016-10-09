//
//  WebSockerServer.m
//  iOS-getUserMedia
//
//  Created by Fathy Boundjadj on 06/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

#import "WebSockerServer.h"

// We don't want to know about libwebsockets warnings
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#import "libwebsockets.h"
#import "private-libwebsockets.h"
#pragma clang diagnostic pop

typedef void (^Callback)();
typedef void (^WritableCallback)(struct lws*);

static int callback_websockets(struct lws *wsi,
                               enum lws_callback_reasons reason,
                               void *user, void *in, size_t len);

static int callback_http(struct lws *wsi,
                         enum lws_callback_reasons reason,
                         void *user, void *in, size_t len);


@interface WebSocketServer()

@property (nonatomic) BOOL stop;
@property (nonatomic) NSMutableArray* clients;
@property (nonatomic) NSMutableArray<WritableCallback>* clientWriteableCallbacks;
@property (nonatomic) NSMutableArray<NSValue*>* clientWriteablePtrs;
@property pthread_mutex_t clientWriteableMutex;

@property dispatch_queue_t queue;
@property struct lws_context *context;
@property struct lws_context_creation_info *ctxInfo;
@property struct lws_protocols *protocols;
@property unsigned char* sendBuffer;
@property int sendBufferLength;
@property dispatch_semaphore_t lockSemaphore;
@property BOOL canCancel;

@end

@implementation WebSocketServer: NSObject

-(instancetype)init {
    if(self = [super init]) {
        self.clients = [NSMutableArray.alloc init];
        self.clientWriteableCallbacks = [NSMutableArray.alloc init];
        self.clientWriteablePtrs = [NSMutableArray.alloc init];
        
        pthread_mutex_init(&_clientWriteableMutex, nil);
        
        self.sendBuffer = nil;
        self.sendBufferLength = 0;
        
        [self initContext];
    }
    
    return self;
}

-(void)addClient:(struct lws*)client {
    NSValue *value = [NSValue value:&client withObjCType:@encode(struct lws*)];
    
    [self.clients addObject:value];
}

-(void)eachClient:(void(^)(struct lws*))block {
    for(NSValue* value in self.clients) {
        struct lws* client = value.pointerValue;
        
        block(client);
    }
}

-(void)pause {
    dispatch_sync(self.queue, ^{
        [self cancelAllWrites];
        [self setStop:YES];
        
        lws_cancel_service(self.context);
    });
}

-(void)start {
    dispatch_async(self.queue, ^{
        NSLog(@"Starting websocket server: %@", self);
        
        if(self.context == nil) {
            NSLog(@"Recreating server context...");
            
            self.context = lws_create_context(self.ctxInfo);
        }

        self.stop = NO;
        [self cancelAllWrites];
        
        while(!self.stop) {
            @autoreleasepool {
                lws_service(self.context, 60 * 60 * 1000); // wait one hour
                
                if(self.context != nil && self.clientWriteableCallbacks.count > 0) {
                    lws_callback_on_writable_all_protocol(self.context, &(self.protocols[1]));
                }
                
                self.canCancel = YES;
            }
        }
        
        lws_context_destroy(self.context);
        self.context = nil;
        
        NSLog(@"Websocket server stopped");
    });
}
-(void)initContext {
    int port = 6001;
    const char *protocol = "jsbridge-protocol";
    
    _stop = NO;
    
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(
        DISPATCH_QUEUE_CONCURRENT, QOS_CLASS_USER_INTERACTIVE, 0
    );
    
    _queue = dispatch_queue_create("WebSockets", queueAttributes);
    
    
    lws_set_log_level(LLL_ERR, lwsl_emit_syslog);
    
    struct lws_protocols protocols[3] = {
        {
            "http-only",
            callback_http,
            0,
            8
        }, {
            protocol,
            callback_websockets,
            sizeof(int),
            1024 * 1024
        }, {nil, nil, 0, 0}
    };

    self.protocols = malloc(sizeof protocols);

    memcpy(self.protocols, protocols, sizeof protocols);
    
    int size = sizeof(struct lws_context_creation_info);
    self.ctxInfo = malloc(size);
    
    memset(self.ctxInfo, 0, size);
    
    self.ctxInfo->port = port;
    self.ctxInfo->iface = NULL;
    self.ctxInfo->protocols = self.protocols;
    self.ctxInfo->ssl_cert_filepath = NULL;
    self.ctxInfo->ssl_private_key_filepath = NULL;
    self.ctxInfo->extensions = nil; //exts;
    self.ctxInfo->gid = -1;
    self.ctxInfo->uid = -1;
    self.ctxInfo->options = 0;
    self.ctxInfo->user = (__bridge void*)self;
    
    [self start];
}

-(void)lockClients:(Callback)block {
    pthread_mutex_lock(&_clientWriteableMutex);
    
    block();
    
    pthread_mutex_unlock(&_clientWriteableMutex);
}
-(void)cancelAllWrites {
    NSLog(@"Canceling all writeable callback");
    
    [self lockClients:^{
        while(_clientWriteableCallbacks.count) {
            WritableCallback cb = [_clientWriteableCallbacks objectAtIndex:0];
            
            cb(nil);
            
            [_clientWriteableCallbacks removeObjectAtIndex:0];
            [_clientWriteablePtrs removeObjectAtIndex:0];
        }
    }];
}

-(void)waitForWriteable:(WritableCallback)block onClient:(struct lws*)wsi {
    [self lockClients:^{
        NSValue *value = [NSValue valueWithPointer:wsi];
        
        [_clientWriteableCallbacks addObject:block];
        [_clientWriteablePtrs addObject:value];
        
        lws_callback_on_writable_all_protocol(_context, &(_protocols[1]));
        
        if(self.canCancel) {
            self.canCancel = NO;
            
            lws_cancel_service(_context);
        }
    }];
}

-(void)onClientAdded:(struct lws*)wsi {
    NSLog(@"Websocket got connection");
    
    [self addClient:wsi];
}

-(void)onConnectionClose:(struct lws*)wsi {
    __block BOOL found = NO;
    
    [self lockClients:^{
        for(int i = 0; i < _clients.count; i++) {
            NSValue* value = _clients[i];
            
            if(wsi == value.pointerValue) {
                [_clients removeObjectAtIndex:i];
                
                for(int i = 0; i < _clientWriteablePtrs.count; i++) {
                    NSValue *value = _clientWriteablePtrs[i];
                    
                    if(value.pointerValue == wsi) {
                        WritableCallback cb = _clientWriteableCallbacks[i];
                        
                        cb(nil);
                        
                        [_clientWriteablePtrs removeObjectAtIndex:i];
                        [_clientWriteableCallbacks removeObjectAtIndex:i];
                        
                        i--;
                    }
                }
                
                NSLog(@"Websocket connection lost, handle removed.");
                
                found = YES;
            }
        }
    }];
    
    if(!found)
        NSLog(@"WebSocket connection lost and client could not be found.");
}

-(void)onSocket:(struct lws*)wsi data:(NSData*)data{
    if(lws_frame_is_binary(wsi)) {
        if(self.onMessageDataBlock)
            self.onMessageDataBlock(data);
    }
    else if(self.onMessageStringBlock) {
        NSString *string = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
        
        self.onMessageStringBlock(string);
    }
}

-(void)onClientWritable:(struct lws*)wsi {
    [self lockClients:^{
        for(int i = 0; i < _clientWriteablePtrs.count; i++) {
            NSValue *value = _clientWriteablePtrs[i];
            struct lws* ptr = value.pointerValue;
            
            if(wsi == ptr) {
                WritableCallback cb = _clientWriteableCallbacks[i];
                
                cb(ptr);
                
                [_clientWriteableCallbacks removeObjectAtIndex:i];
                [_clientWriteablePtrs removeObjectAtIndex:i];
                
                break;
            }
        }
    }];
}

-(void)writeJSON:(id)json withCompletionBlock:(Callback)block {
    NSError *err;
    NSData *data = [NSJSONSerialization dataWithJSONObject:json options:0 error:&err];
    NSString *string = [NSString.alloc initWithData:data encoding:NSUTF8StringEncoding];
    
    [self writeString:string withCompletionBlock:block];
}
-(void)writeString:(NSString*)string withCompletionBlock:(Callback)block {
    if(_clients.count == 0)
        return block();
    
    dispatch_group_t group = dispatch_group_create();
    
    [self eachClient:^(struct lws* wsi) {
        dispatch_group_enter(group);
        
        [self waitForWriteable:^(struct lws* wsi){
            if(wsi == nil)
                return block();
            
            unsigned char* buffer = malloc(LWS_SEND_BUFFER_PRE_PADDING + string.length + LWS_SEND_BUFFER_POST_PADDING);
            
            memcpy(&buffer[LWS_SEND_BUFFER_PRE_PADDING], string.UTF8String, string.length);
            
            lws_write(wsi, &buffer[LWS_SEND_BUFFER_PRE_PADDING], string.length, LWS_WRITE_TEXT);
            free(buffer);
            
            dispatch_group_leave(group);
        } onClient:wsi];
    }];
    
    dispatch_async(self.queue, ^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        block();
    });
}
-(void)writeData:(NSData*)data {
    [self writeData:data withCompletionBlock:nil];
}
-(void)writeDatas:(NSArray<NSData*>*)datas {
    [self writeDatas:datas withCompletionBlock:nil];
}
-(void)writeData:(NSData*)data withCompletionBlock:(Callback)block {
    if(self.clients.count == 0)
        return block();
    
    dispatch_group_t group = dispatch_group_create();

    [self eachClient:^(struct lws* client) {
        dispatch_group_enter(group);

        [self writeData:data toSocket:client withCompletionBlock:^{
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_async(self.queue, ^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        block();
    });
}

-(void)writeDatas:(NSArray<NSData*>*)datas withCompletionBlock:(Callback)block {
    if(self.clients.count == 0)
        return block();
    
    dispatch_group_t group = dispatch_group_create();
    
    [self eachClient:^(struct lws* client) {
        dispatch_group_enter(group);
        
        [self writeDatas:datas toSocket:client withCompletionBlock:^{
            dispatch_group_leave(group);
        }];
    }];
    
    dispatch_async(self.queue, ^{
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        block();
    });
}
-(void)writeData:(NSData*)data
        toSocket:(struct lws*)wsi
withCompletionBlock:(Callback)block {
    [self writeDatas:@[data] withCompletionBlock:block];
}
-(void)writeDatas:(NSArray<NSData*>*)datas
        toSocket:(struct lws*)wsi
withCompletionBlock:(Callback)block {
    [self waitForWriteable:^(struct lws* wsi) {
        if(wsi == nil)
            return block();
        
        int size = 0;
        
        for(NSData *data in datas) {
            size += data.length;
        }
        
        int fullSize = LWS_SEND_BUFFER_PRE_PADDING + size + LWS_SEND_BUFFER_POST_PADDING;
        
        if(_sendBuffer == nil || fullSize > _sendBufferLength) {
            if(_sendBuffer != nil)
                free(_sendBuffer);
            
            _sendBuffer = (unsigned char*)malloc(fullSize);
            _sendBufferLength = fullSize;
            
            NSLog(@"Allocating buffer of size : %d", fullSize);
        }
        
        
        int pad = 0;
        
        for(NSData *data in datas) {
            NSUInteger length = data.length;
            
            memcpy(&_sendBuffer[LWS_SEND_BUFFER_PRE_PADDING + pad], data.bytes, length);
            
            pad += length;
        }
        
        lws_write(wsi, &_sendBuffer[LWS_SEND_BUFFER_PRE_PADDING], size, LWS_WRITE_BINARY);
        
        if(block)
            block();
    } onClient:wsi];
}

@end

static int callback_http(struct lws *wsi,
                         enum lws_callback_reasons reason,
                         void *user, void *in, size_t len)
{
    return 0;
}

static int callback_websockets(struct lws *wsi,
                               enum lws_callback_reasons reason,
                               void *user, void *in, size_t len) {
    WebSocketServer *server = (__bridge WebSocketServer*)lws_context_user(wsi->context);
    
    switch (reason) {
        case LWS_CALLBACK_ESTABLISHED:
            [server onClientAdded:wsi];
            
            break;
        case LWS_CALLBACK_RECEIVE: {
            NSData *data = [NSData dataWithBytes:(const void *)in length:len];
            
            [server onSocket:wsi data:data];
            
            break;
        }
        case LWS_CALLBACK_SERVER_WRITEABLE: {
            [server onClientWritable:wsi];
            
            break;
        }
        case LWS_CALLBACK_CLOSED: {
            [server onConnectionClose: wsi];
            
            break;
        }
        default:
            break;
    }
    
    return 0;
}

