/// Copyright 2016 MacDevTeam All rights reserved.
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

#import "AppDelegate.h"
#import "UserConfigAgentXPCAgentProtocol.h"
#import <SystemConfiguration/SystemConfiguration.h>

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *ProgressVisualiser;
@property (weak) IBOutlet NSProgressIndicator *ProgressBar;
@property (weak) IBOutlet NSTextField *ProgressMsg;
@property (weak) IBOutlet NSTextField *ProgressUsername;
@property (weak) IBOutlet NSImageView *ProgressImage;

@property NSXPCConnection *connectionToService;
@property id remoteObject;
@property (nonatomic, strong) NSString *UserPassword;

@end

@implementation AppDelegate

// ##################################################################################################################
// ##################################################################################################################
// Process passed Actions: depends on "Handle Observer Jobs" - we need to enhance this!
// e.g.:
// - we can listen to close App
// - we can check if an App is closed
// - we need to check which version number of the App is launched and we want to set settings
//

// Execute Script
- (void)m_ExecScript:(NSString *)ScriptPath :(BOOL)ProvidePassword :(NSString *)VisualizeMsg {
    NSLog(@"Info: Enable progress visualizer");
    if (![VisualizeMsg isEqualToString:@""]) {
        [self DisplayProgressVisualizer:VisualizeMsg];
        // Give the user a chance to see the configuration message
        [NSThread sleepForTimeInterval:3];
    } else {
        NSLog(@"Info: We do not display a GUI. Process Action silent.");
    }
    
    NSTask *task = [[NSTask alloc] init];
    NSLog(@"Info: Execute Script: %@", ScriptPath);
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:ScriptPath]) {
        // Set launch path
        [task setLaunchPath: ScriptPath];
        
        // Prepare Write Pipe (stdin)
        NSPipe *writePipe = [NSPipe pipe];
        NSFileHandle *writeHandle = [writePipe fileHandleForWriting];
        [task setStandardInput: writePipe];
        
        // Prepare Read Pipe (stdout)
        NSPipe *readPipe = [NSPipe pipe];
        [task setStandardOutput: readPipe];
        NSFileHandle *fileReadPipe = [readPipe fileHandleForReading];
        
        // Define Script Environment
        NSDictionary *environmentDictionary = [[NSProcessInfo processInfo] environment];
        NSMutableDictionary *environmentmutableDictionary = [environmentDictionary mutableCopy];
            [environmentmutableDictionary setValue:NSUserName() forKey:@"MY_SHORTNAME"];
            [environmentmutableDictionary setValue:NSFullUserName() forKey:@"MY_REALNAME"];
            [environmentmutableDictionary setValue:NSFullUserName() forKey:@"MY_FULLNAME"];
            // We need to be more detailed. This cannot be the truth! Ask OpenDirectory Framework!
            [environmentmutableDictionary setValue:[[NSFullUserName() componentsSeparatedByString:@" "] objectAtIndex:0] forKey:@"MY_FIRSTNAME"];
            [environmentmutableDictionary setValue:[[NSFullUserName() componentsSeparatedByString:@" "] objectAtIndex:1] forKey:@"MY_LASTNAME"];
            uid_t uid;
            gid_t gid;
            SCDynamicStoreCopyConsoleUser(nil, &uid, &gid);
            [environmentmutableDictionary setValue:[NSNumber numberWithInt:uid] forKey:@"MY_UID"];
            [environmentmutableDictionary setValue:[NSNumber numberWithInt:gid] forKey:@"MY_GUID"];
            NSLog(@"DEBUG: Script environment: %@", environmentmutableDictionary);
        [task setEnvironment:environmentmutableDictionary];
        
        // Launch Script Task
        [task launch];
        
        if (ProvidePassword == YES) {
            // Write Stdin password data to Script Task
            if (_UserPassword == nil || [_UserPassword isEqualToString:@""]) {
                NSLog(@"Warning: No valid user password to pass");
            } else {
                NSData *StdinData = [_UserPassword dataUsingEncoding:NSUTF8StringEncoding];
                [writeHandle writeData:StdinData];
                [writeHandle closeFile];
            }
        }
       
        // Tell Task to wait until exit
        [task waitUntilExit];
        
        if (![task isRunning]) {
            
            // Read Stdout data
            NSData *dataReadPipe = [fileReadPipe readDataToEndOfFile];
            NSString *SubScriptOutput = [[NSString alloc] initWithData: dataReadPipe encoding: NSUTF8StringEncoding];
            NSLog(@"Info: Script output: %@", SubScriptOutput);
            
            // Evaluate Termination status
            if ([task terminationStatus] == 0) {
                NSLog(@"Info: Script returned success");
            } else {
                NSLog(@"Info: Script returned error");
            }
        }
        
        NSLog(@"Info Script: \"%@\" Status: complete", ScriptPath);
    } else {
        NSLog(@"Info: Script Path not found! SubScript Not Executed!");
    }
    
    [self CloseProgressVisualizer];
}

- (NSString *)CheckAppState:(NSString *)AppToCheck {
    for (NSRunningApplication *ReadAppToCheck in [[NSWorkspace sharedWorkspace] runningApplications]) {
        if ([AppToCheck isEqualToString:[ReadAppToCheck bundleIdentifier]]) {
            return @"ACTIVE";
        }
    }
    return @"INACTIVE";
}

// ##################################################################################################################
// ##################################################################################################################
- (NSArray *)m_GetAllConfigFiles:(NSString *)PathToConfigFiles {
    BOOL isDir = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:PathToConfigFiles isDirectory:&isDir]) {
        NSArray *AllConfigFiles = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[NSURL fileURLWithPath:PathToConfigFiles]
                                                                includingPropertiesForKeys:@[]
                                                                                   options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                                     error:nil];
        NSArray *AllConfigFilesFiltered = [AllConfigFiles filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"pathExtension == 'plist'"]];
        
        if (AllConfigFilesFiltered != nil) {
            return AllConfigFilesFiltered;
        } else {
            NSLog(@"Info: There are no ConfigFiles to evaluate");
        }
    } else {
        NSLog(@"Warning: Can not find configured PathToConfigFiles directory: %@", PathToConfigFiles);
    }
    return nil;
}



// Search for a configuration file for a passed "TargetApp"
- (NSString *)SearchConfigFile:(NSString *)TargetApp {
    
    // Search for ConfigFiles in the passed PathToConfigFiles
    NSString *PathToConfigFiles = [[NSUserDefaults standardUserDefaults] stringForKey:@"PathToConfigFiles"];
    if (PathToConfigFiles == nil) {
        PathToConfigFiles = Default_PathToConfigFiles;
    }
    BOOL isDir = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:PathToConfigFiles isDirectory:&isDir]) {
        NSArray *AllConfigFiles = [self m_GetAllConfigFiles:PathToConfigFiles];
        if (AllConfigFiles != nil) {
            for (NSURL *ConfigFile in AllConfigFiles) {
                // Enumerate each .plist file in directory
                NSDictionary *PathToConfigFile = [[NSDictionary alloc] initWithContentsOfURL:[NSURL URLWithString:ConfigFile.absoluteString]];
                NSString *readTargetApp = [[PathToConfigFile objectForKey:@"TargetApp"] lowercaseString];
                NSString *readTargetAppState = [[PathToConfigFile objectForKey:@"TargetAppState"] lowercaseString];
                if ([readTargetApp isEqualToString:TargetApp.lowercaseString] & [readTargetAppState isEqualToString:@"launched"]) {
                    return [NSString stringWithFormat:@"%@", ConfigFile];
                }
            }
        } else {
            NSLog(@"Info: There are no ConfigFiles to evaluate");
        }
    } else {
        NSLog(@"Warning: Can not find configured PathToConfigFiles directory: %@", PathToConfigFiles);
    }
    return nil;
}


// ##################################################################################################################
// ##################################################################################################################
// Handle the user domain: set/read values
- (void)SetUserPrefs:(NSString *)UserPrefsKey :(NSString *)UserPrefsValue {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:UserPrefsValue forKey:UserPrefsKey];
    [prefs synchronize];
}

- (NSString *)ReadUserPrefs:(NSString *)KeyToRead {
    NSString *PrefsValue = [[NSUserDefaults standardUserDefaults] objectForKey:KeyToRead];
    return PrefsValue;
}

// ##################################################################################################################
// ##################################################################################################################
// ProgressBar Visualiser Open/Close Actions
- (void)DisplayProgressVisualizer:(NSString *)ProgressMsg {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.ProgressUsername setStringValue:[NSString stringWithFormat:@"Run configuration for user: %@", NSUserName()]];
            [self.ProgressMsg setStringValue:ProgressMsg];
            [self.ProgressVisualiser makeKeyAndOrderFront:self];
            [self.ProgressBar startAnimation:self];
        });
    });
}

- (void)CloseProgressVisualizer {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.ProgressMsg setStringValue:@""];
            [self.ProgressBar stopAnimation:self];
            [self.ProgressVisualiser close];
        });
    });
}


// ##################################################################################################################
// ##################################################################################################################
// Handle Observer Jobs
- (void)m_HandleOpenApps:(NSNotification *)notification {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Pass in NSWorkspaceApplicationKey
        NSRunningApplication *runApp = [[notification userInfo] valueForKey:@"NSWorkspaceApplicationKey"];
        NSLog(@"Info: Detected App activation: runApp.bundleIdentifier: %@", runApp.bundleIdentifier);
        
        // Search for a configuration file for the passed "runApp.bundleIdentifier".
        NSString *SessionConfigFile = [self SearchConfigFile:[NSString stringWithFormat:@"%@", runApp.bundleIdentifier]];
        if (SessionConfigFile != nil) {
            NSLog(@"Info: Found a SessionConfig file to process: SessionConfigFile: %@", SessionConfigFile);
            
            // Eval configuration dictionary
            NSDictionary *ConfigFileDict = [[NSDictionary alloc] initWithContentsOfURL:[NSURL URLWithString:SessionConfigFile]];
            
            // Define RunTime ConfigName based on Script configuration name
            NSString *ConfigName = [[[NSURL URLWithString:SessionConfigFile] lastPathComponent] stringByDeletingPathExtension];
            NSString *ConfigNameRunState = [NSString stringWithFormat:@"RUNSTATE_%@", ConfigName];
            
            // Check if we can set the settings. Check if the App is launched!
            NSString *CheckAppState = [self CheckAppState:runApp.bundleIdentifier];
            NSLog(@"Info: Read configuration: Return status CheckAppState: %@", CheckAppState);
            
            if ([CheckAppState isEqualToString:@"ACTIVE"]) {
                
                NSLog(@"Info: Process configuration: %@", ConfigName);
                
                // Read config details
                NSString *ScriptPath = [ConfigFileDict objectForKey:@"ScriptPath"];
                BOOL ProvidePassword = [[ConfigFileDict valueForKey:@"ProvidePassword"] boolValue];
                NSString *VisualizeMsg = [ConfigFileDict valueForKey:@"VisualizeMsg"];
                if (VisualizeMsg == nil) {
                    VisualizeMsg = @"";
                }
                
                // Read user preferences (RUNSTATE)
                NSString *ReadPrefsConfigName = [self ReadUserPrefs:ConfigName];
                NSString *ReadPrefsConfigNameRunState = [self ReadUserPrefs:ConfigNameRunState];
                NSLog(@"Info: ReadPrefsConfigName: %@", ReadPrefsConfigName);
                NSLog(@"Info: ReadPrefsConfigNameRunState: %@", ReadPrefsConfigNameRunState);
                
                
                // --> process passed kind of script
                if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"once"]) {
                    // run only once
                    if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"once"] && ![ReadPrefsConfigNameRunState isEqualToString:@"1"]) {
                        NSLog(@"Info: Repeat is set to \"once\". We process the Action!");
                        // Process the Script
                        [self m_ExecScript:ScriptPath :ProvidePassword :VisualizeMsg];
                        
                        [self SetUserPrefs:ConfigName :@"once"];
                        [self SetUserPrefs:ConfigNameRunState :@"1"];
                        
                    } else {
                        NSLog(@"Info: Repeat is set to \"once\". We already have processed the Action. Skip!");
                    }
                } else if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"always"]) {
                    // run always
                    NSLog(@"Info: Repeat is set to \"always\". We process the Action!");
                    // Process the Script
                    [self m_ExecScript:ScriptPath :ProvidePassword :VisualizeMsg];
                    
                    [self SetUserPrefs:ConfigName :@"always"];
                    [self SetUserPrefs:ConfigNameRunState :@"1"];
                    
                } else if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"never"]) {
                    // run never
                    NSLog(@"Info: Repeat is set to \"never\". We skip!");
                }
                
            } else {
                NSLog(@"Info: App can not be configured. App is not launched. We skip!");
            }
        }
    });
    
}

- (void)m_ProcessClosedApps {
    
    // Get all configuration files
    NSString *PathToConfigFiles = [[NSUserDefaults standardUserDefaults] stringForKey:@"PathToConfigFiles"];
    if (PathToConfigFiles == nil) {
        PathToConfigFiles = Default_PathToConfigFiles;
    }
    BOOL isDir = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:PathToConfigFiles isDirectory:&isDir]) {
        NSArray *AllConfigFiles = [self m_GetAllConfigFiles:PathToConfigFiles];
        NSLog(@"DEBUG: AllConfigFiles: %@", AllConfigFiles);
        
        // Eval all configuration files
        for (NSURL *ConfigFile in AllConfigFiles) {
            
            // Eval configuration dictionary
            NSDictionary *ConfigFileDict = [[NSDictionary alloc] initWithContentsOfURL:ConfigFile];
            
            // Define RunTime ConfigName based on Script configuration name
            NSString *ConfigName = [[ConfigFile lastPathComponent] stringByDeletingPathExtension];
            NSString *ConfigNameRunState = [NSString stringWithFormat:@"RUNSTATE_%@", ConfigName];
            
            // Process TargetAppState = closed SubScripts
            if ([[[ConfigFileDict objectForKey:@"TargetAppState"] lowercaseString] isEqualToString:@"closed"] || [[ConfigFileDict objectForKey:@"TargetAppState"] lowercaseString] == nil) {
                
                NSLog(@"Info: Process configuration: %@", ConfigName);
                
                // Read config details
                NSString *ScriptPath = [ConfigFileDict objectForKey:@"ScriptPath"];
                BOOL ProvidePassword = [[ConfigFileDict valueForKey:@"ProvidePassword"] boolValue];
                NSString *VisualizeMsg = [ConfigFileDict valueForKey:@"VisualizeMsg"];
                if (VisualizeMsg == nil) {
                    VisualizeMsg = @"";
                }
                
                // Read user preferences (RUNSTATE)
                NSString *ReadPrefsConfigName = [self ReadUserPrefs:ConfigName];
                NSString *ReadPrefsConfigNameRunState = [self ReadUserPrefs:ConfigNameRunState];
                NSLog(@"Info: ReadPrefsConfigName: %@", ReadPrefsConfigName);
                NSLog(@"Info: ReadPrefsConfigNameRunState: %@", ReadPrefsConfigNameRunState);
                
                // --> process passed script
                if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"once"]) {
                    // run only once
                    if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"once"] && ![ReadPrefsConfigNameRunState isEqualToString:@"1"]) {
                        NSLog(@"Info: Repeat is set to \"once\". We process the Action!");
                        // Process the Script
                        [self m_ExecScript:ScriptPath :ProvidePassword :VisualizeMsg];
                        
                        [self SetUserPrefs:ConfigName :@"once"];
                        [self SetUserPrefs:ConfigNameRunState :@"1"];
                        
                    } else {
                        NSLog(@"Info: Repeat is set to \"once\". We already have processed the Action. Skip run.");
                    }
                } else if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"always"]) {
                    // run always
                    NSLog(@"Info: Repeat is set to \"always\". We process the Action!");
                    // Process the Script
                    [self m_ExecScript:ScriptPath :ProvidePassword :VisualizeMsg];
                    
                    [self SetUserPrefs:ConfigName :@"always"];
                    [self SetUserPrefs:ConfigNameRunState :@"1"];
                    
                } else if ([[ConfigFileDict objectForKey:@"Repeat"] isEqualToString:@"never"]) {
                    // run never
                    NSLog(@"Info: Repeat is set to \"never\". We skip!");
                }
            }
        }
    } else {
        NSLog(@"Warning: Can not find configured PathToConfigFiles directory: %@", PathToConfigFiles);
    }
}



// ##################################################################################################################
// ################################## -- App Init Actions -- ####################################################
// ##################################################################################################################
- (void)m_XPCConnect: (void (^)(BOOL finished)) completionBlock {
    self.connectionToService = [[NSXPCConnection alloc]
                                initWithMachServiceName:kUserConfigAgentXPCAgentServiceName
                                options:NSXPCConnectionPrivileged];
    self.connectionToService.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:
                                                      @protocol(UserConfigAgentXPCAgentProtocol)];
    [self.connectionToService resume];
    
    self.remoteObject = [self.connectionToService remoteObjectProxyWithErrorHandler:^(NSError *err) {
        if (err) {
            NSLog(@"Error: UserConfigAgentXPCAgent connection failed. Error code: %@", [err description]);
        } else {
            NSLog(@"Info: UserConfigAgentXPCAgent connected");
        }
    }];
    if (completionBlock != nil) completionBlock(TRUE);
}


- (void)m_XPCGetPW: (void (^)(BOOL finished)) completionBlock {
    [self.remoteObject getPasswordWithReply:^(NSData *UserPassword) {
        if (UserPassword) {
            _UserPassword = (NSString *)[NSKeyedUnarchiver unarchiveObjectWithData:UserPassword];
        } else {
            NSLog(@"ERROR: Can not get User-Password from UserConfigAgentXPCAgent");
        }
        if (completionBlock != nil) completionBlock(TRUE);
    }];
}

// Yosemite: Ability to check for the new dark mode
- (BOOL)CheckOSXUIMode {
    NSString *OSX_MODE = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleInterfaceStyle"];
    NSLog(@"Info: OS X UI Mode: %@", OSX_MODE);
    if (OSX_MODE != nil) {
        if ([OSX_MODE isEqualToString:@"Dark"]) {
            return 1;
        } else {
            return 0;
        }
    }
    return 0;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    
    // Check for trigger files
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:AgentTriggerPath]) {
        NSLog(@"Info: Remove trigger file");
        [[NSFileManager defaultManager] removeItemAtPath:AgentTriggerPath error:&error];
        if(error){
            NSLog(@"Error: Removing trigger file %@", [error description]);
        }
    }
    
    // Evaluate the Run Mode
    NSString *RunMode = [[NSUserDefaults standardUserDefaults] stringForKey:@"RunMode"];
    NSLog(@"Info: Passed RunMode: %@", RunMode);
    if (RunMode == nil || ![RunMode isEqualToString:@"AgentAqua"]) {
        NSLog(@"Info: No valid RunMode passed to UserConfigAgent. Terminate.");
        [NSApp terminate:self];
    }
    
    // Get & Check config file directory
    NSString *PathToConfigFiles = [[NSUserDefaults standardUserDefaults] stringForKey:@"PathToConfigFiles"];
    if (PathToConfigFiles == nil) {
        PathToConfigFiles = Default_PathToConfigFiles;
    }
    BOOL isDir = YES;
    if ([[NSFileManager defaultManager] fileExistsAtPath:PathToConfigFiles isDirectory:&isDir]) {
        NSLog(@"Info: PathToConfigFiles: %@", PathToConfigFiles);
    } else {
        NSLog(@"Warning: Can not find PathToConfigFiles: %@", PathToConfigFiles);
        [NSApp terminate:self];
    }
    
    // Evaluate Blacklisted users
    NSString *ActiveUserName = NSUserName();
    NSLog(@"Info: Run UserConfigAgent as User: %@", ActiveUserName);
    NSArray *BlackListUser = [[NSUserDefaults standardUserDefaults] objectForKey:@"BlackListUser"];
    if (BlackListUser != nil) {
        if ([BlackListUser containsObject:ActiveUserName]) {
            NSLog(@"Warning: Close UserConfigAgent - we run as blacklist user! Terminate Agent.");
            [NSApp terminate:self];
        }
    }
    
    // Observe Lock Screen events
    NSDistributedNotificationCenter *center = [NSDistributedNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(EvalScreenLockEvent:)
                   name:@"com.apple.screenIsLocked"
                 object:nil];
    
    // Initialize the ProgressVisualiser Window (Look and Level)
    if ([self CheckOSXUIMode] == 1) {
        [self.ProgressVisualiser setAppearance:[NSAppearance appearanceNamed:NSAppearanceNameVibrantDark]];
    }
    [self.ProgressVisualiser setLevel:NSScreenSaverWindowLevel];
    [self.ProgressVisualiser setCanBecomeVisibleWithoutLogin:YES];
    [self.ProgressVisualiser setCanHide:NO];
    [self.ProgressVisualiser setMovableByWindowBackground:YES];
    [self.ProgressVisualiser makeFirstResponder:nil];
    [self.ProgressVisualiser setTitleVisibility:NO];
    [self.ProgressVisualiser setOpaque:YES];
    [NSApp activateIgnoringOtherApps:YES];
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    
    NSLog(@"Info: Connect to UserConfigAgentXPCAgent ...");
    [self m_XPCConnect: ^(BOOL success) {
        if (success) {
            NSLog(@"Info: Get User Password from UserConfigAgentXPCAgent ...");
            [self m_XPCGetPW: ^(BOOL success) {
                if (success) {
                    NSLog(@"Info: Start Observer ...");
                    
                    NSLog(@"Info: Check if there are settings for \"closed\" Apps");
                    [self m_ProcessClosedApps];
                    
                    NSLog(@"Info: Agent launched. Keep on observing NSWorkspace sharedApplications ..");
                    NSLog(@"Info: Listen for settings for \"launched\" Apps");
                    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                                           selector:@selector(m_HandleOpenApps:)
                                                                               name:NSWorkspaceDidLaunchApplicationNotification
                                                                             object:nil];
                } else {
                    NSLog(@"Warning: Get User Password Failed. Terminate Agent.");
                    [NSApp terminate:self];
                }
            }];
        } else {
            NSLog(@"Warning: UserConfigAgentXPCAgent connection failed. Terminate Agent.");
            [NSApp terminate:self];
        }
    }];
}

- (void)EvalScreenLockEvent:(NSNotification*)notification {
    NSLog(@"Info: Recieved Screen Lock event. Close UserConfigAgentGUIAgent and wait for re-activation. Terminate Agent.");
    [NSApp terminate:self];
}

-(void)applicationWillTerminate:(NSNotification *)notification {
  [self.connectionToService invalidate];
}

@end
