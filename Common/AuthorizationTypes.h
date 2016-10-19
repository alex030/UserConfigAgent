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

#import <Security/AuthorizationPlugin.h>

// Context & Hint Keys
#define kKMAuthAuthenticationAuthority "dsAttrTypeStandard:AuthenticationAuthority"
#define kKMAuthUID "uid"
#define kKMAuthGID "gid"
#define kKMAuthTokenName "token-name"
#define kKMAuthAuthorizeRight "authorize-right"
#define kKMAuthSuggestedUser "suggested-user"
#define kKMAuthClientPath "client-path"

// Plugin Data Types
enum {
  kMechanismMagic = 'Mchn',
  kPluginMagic = 'PlgN',
};

typedef struct {
  OSType magic;
  const AuthorizationCallbacks *callbacks;
} PluginRecord;

typedef struct {
  OSType magic;
  AuthorizationEngineRef engineRef;
  const PluginRecord *pluginRecord;
} MechanismRecord;
