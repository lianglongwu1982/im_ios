//
//  CustomerMessageHandler.m
//  imkit
//
//  Created by houxh on 16/1/19.
//  Copyright © 2016年 beetle. All rights reserved.
//

#import "CustomerMessageHandler.h"
#import "MessageDB.h"
#import "Message.h"
#import "CustomerMessageDB.h"

@implementation CustomerMessageHandler
+(CustomerMessageHandler*)instance {
    static CustomerMessageHandler *m;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!m) {
            m = [[CustomerMessageHandler alloc] init];
        }
    });
    return m;
}

-(BOOL)handleCustomerSupportMessage:(CustomerMessage*)msg {
    ICustomerMessage *m = [[ICustomerMessage alloc] init];
    m.customerAppID = msg.customerAppID;
    m.customerID = msg.customerID;
    m.storeID = msg.storeID;
    m.sellerID = msg.sellerID;
    m.isSupport = YES;
    m.sender = msg.customerID;
    m.receiver = msg.storeID;
    m.rawContent = msg.content;
    m.timestamp = msg.timestamp;
    BOOL r = [[CustomerMessageDB instance] insertMessage:m uid:msg.storeID];
    if (r) {
        msg.msgLocalID = m.msgLocalID;
    }
    return r;
}

-(BOOL)handleMessage:(CustomerMessage*)msg {
    ICustomerMessage *m = [[ICustomerMessage alloc] init];
    m.customerAppID = msg.customerAppID;
    m.customerID = msg.customerID;
    m.storeID = msg.storeID;
    m.sellerID = msg.sellerID;
    m.isSupport = NO;
    m.sender = msg.customerID;
    m.receiver = msg.storeID;
    m.rawContent = msg.content;
    m.timestamp = msg.timestamp;
    if (self.uid == msg.customerID) {
        m.flags = m.flags | MESSAGE_FLAG_ACK;
    }
    
    if (m.type == MESSAGE_REVOKE) {
        BOOL r = YES;
        MessageRevoke *revoke = m.revokeContent;
        int msgId = [[CustomerMessageDB instance] getMessageId:revoke.msgid];
        if (msgId > 0) {
            r = [[CustomerMessageDB instance] updateMessageContent:msgId content:msg.content];
            [[CustomerMessageDB instance] removeMessageIndex:msgId uid:msg.storeID];
        }
        return r;
    } else {
        BOOL r = [[CustomerMessageDB instance] insertMessage:m uid:msg.storeID];
        if (r) {
            msg.msgLocalID = m.msgLocalID;
        }
        return r;
    }
}

-(BOOL)handleMessageACK:(CustomerMessage*)msg {
    if (msg.msgLocalID > 0) {
        return [[CustomerMessageDB instance] acknowledgeMessage:msg.msgLocalID uid:msg.storeID];
    } else {
        MessageContent *content = [IMessage fromRaw:msg.content];
        if (content.type == MESSAGE_REVOKE) {
            MessageRevoke *revoke = (MessageRevoke*)content;
            int revokedMsgId = [[CustomerMessageDB instance] getMessageId:revoke.msgid];
            if (revokedMsgId > 0) {
                [[CustomerMessageDB instance]  updateMessageContent:revokedMsgId content:msg.content];
                [[CustomerMessageDB instance] removeMessageIndex:revokedMsgId uid:msg.storeID];
            }
        }
        return YES;
    }
}

-(BOOL)handleMessageFailure:(CustomerMessage*)msg {
    CustomerMessageDB *db = [CustomerMessageDB instance];
    return [db markMessageFailure:msg.msgLocalID uid:msg.storeID];
}

@end