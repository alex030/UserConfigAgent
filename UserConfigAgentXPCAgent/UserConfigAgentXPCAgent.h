/// Copyright 2015 Google Inc. All rights reserved.
///
/// Licensed under the Apache License, Version 2.0 (the "License");
/// you may not use this file except in compliance with the License.
/// You may obtain a copy of the License at
///
///    http://www.apache.org/licenses/LICENSE-2.0
///
///    Unless required by applicable law or agreed to in writing, software
///    distributed under the License is distributed on an "AS IS" BASIS,
///    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///    See the License for the specific language governing permissions and
///    limitations under the License.
///
///
/// Cleaned/Enhanced by Alexander Wolpert @MacDevTeam 2016
///

#import "UserConfigAgentXPCAgentProtocol.h"

#import <Foundation/Foundation.h>

@interface UserConfigAgentXPCAgent : NSObject <NSXPCListenerDelegate, UserConfigAgentXPCAgentProtocol>

#define AgentTriggerPath @"/tmp/.com.macdevteam.UserConfigAgentGUIAgent.Run"

- (void)setPassword:(NSData *)inPassword withReply:(void (^)(BOOL))reply;
- (void)getPasswordWithReply:(void (^)(NSData *))reply;
- (void)triggerGUIAgent:(NSString *)inUsername withReply:(void (^)(BOOL))reply;
- (void)run;

@end
