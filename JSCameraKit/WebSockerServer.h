//
//  WebSockerServer.h
//  iOS-getUserMedia
//
//  Created by Fathy Boundjadj on 06/10/2016.
//  Copyright © 2016 Fathy Boundjadj. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef void (^Callback)();
typedef void(^OnMessageDataBlock)(NSData* message);
typedef void(^OnMessageStringBlock)(NSString* message);

@interface WebSocketServer: NSObject

-(void)pause;
-(void)start;
-(void)cancelAllWrites;

-(void)writeJSON:(id)json withCompletionBlock:(Callback)block;

-(void)writeData:(NSData*)data withCompletionBlock:(Callback)block;
-(void)writeDatas:(NSArray<NSData*>*)data withCompletionBlock:(Callback)block;
-(void)writeData:(NSData*)data;
-(void)writeDatas:(NSArray<NSData*>*)data;

-(void)writeString:(NSString*)string withCompletionBlock:(Callback)callback;

@property (nonatomic) OnMessageDataBlock onMessageDataBlock;
@property (nonatomic) OnMessageStringBlock onMessageStringBlock;

@end
