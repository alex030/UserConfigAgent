#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#
#
# Cleaned/Enhanced by Alexander Wolpert @MacDevTeam 2016
#


if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

updatearg=""
for arg in $*; do
  if [ "$arg" == "--restore-screensaver" ]; then
    updatearg=$arg
  else
    echo "unknown argument: $arg"
    exit 1
  fi
done

/usr/bin/env python /Library/Security/SecurityAgentPlugins/UserConfigAgentPlugin.bundle/Contents/Resources/update_authdb.py remove $updatearg
/bin/rm -rf /Library/Security/SecurityAgentPlugins/UserConfigAgentPlugin.bundle
/bin/rm /Library/LaunchAgents/com.macdevteam.userconfigagentguiagent.plist
/bin/rm /Library/LaunchDaemons/com.macdevteam.userconfigagentxpcagent.plist
/bin/rm /Library/Preferences/com.macdevteam.userconfigagent.plist

user=$(/usr/bin/stat -f '%u' /dev/console)
[[ -z "$user" ]] && exit 0
/bin/launchctl asuser ${user} /bin/launchctl remove com.macdevteam.userconfigagentguiagent
/bin/launchctl remove com.macdevteam.userconfigagentxpcagent
