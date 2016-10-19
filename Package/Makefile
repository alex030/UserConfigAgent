#
#  Package Makefile for UserConfigAgent
#  Requires TheLuggage (github.com/unixorn/luggage) to be installed.
#
USE_PKGBUILD=1
LUGGAGE:=/usr/local/share/luggage/luggage.make
include ${LUGGAGE}

TITLE:=UserConfigAgent
REVERSE_DOMAIN:=com.macdevteam

PACKAGE_VERSION:=$(shell defaults read $$PWD/../UserConfigAgentPlugin/Info.plist CFBundleVersion)

PAYLOAD:=pack-SecurityAgentPlugin-UserConfigAgentPlugin.bundle \
				pack-Library-LaunchAgents-com.macdevteam.userconfigagentguiagent.plist \
				pack-Library-LaunchDaemons-com.macdevteam.userconfigagentxpcagent.plist \
				pack-script-postinstall \
				pack-UserConfigAgentDefaultConfigPath

UserConfigAgentPlugin.bundle:
	@pod install
	@cd .. && xcodebuild -workspace UserConfigAgent.xcworkspace -scheme UserConfigAgentPlugin -configuration Archive -derivedDataPath build
	@cp -R ../build/Build/Products/Release/UserConfigAgentPlugin.bundle .

l_Library_Security: l_Library
	@sudo mkdir -p ${WORK_D}/Library/Security
	@sudo chown root:admin ${WORK_D}/Library/Security
	@sudo chmod 755 ${WORK_D}/Library/Security

l_Library_Security_SecurityAgentPlugins: l_Library_Security
	@sudo mkdir -p ${WORK_D}/Library/Security/SecurityAgentPlugins
	@sudo chown root:admin ${WORK_D}/Library/Security/SecurityAgentPlugins
	@sudo chmod 755 ${WORK_D}/Library/Security/SecurityAgentPlugins

l_Library_Application_Support_UserConfigAgent: l_Library_Application_Support
	@sudo mkdir -p "${WORK_D}/Library/Application Support/UserConfigAgent/ConfigFiles/"
	@sudo mkdir -p "${WORK_D}/Library/Application Support/UserConfigAgent/ScriptFiles/"
	@sudo chown -R root:admin "${WORK_D}/Library/Application Support/UserConfigAgent/"
	@sudo chmod go=u-w "${WORK_D}/Library/Application Support/UserConfigAgent/"
	@sudo chmod -R go=u-w,a+x "${WORK_D}/Library/Application Support/UserConfigAgent/"

pack-UserConfigAgentDefaultConfigPath: l_Library_Application_Support_UserConfigAgent

pack-SecurityAgentPlugin-%: % l_Library_Security_SecurityAgentPlugins
	@sudo ${DITTO} --noqtn "${<}" ${WORK_D}/Library/Security/SecurityAgentPlugins/"${<}"
	@sudo chown -R root:wheel ${WORK_D}/Library/Security/SecurityAgentPlugins/"${<}"
	@sudo chmod 755 ${WORK_D}/Library/Security/SecurityAgentPlugins/"${<}"

clean: myclean

myclean:
	rm -rf ${TITLE}-*.pkg
	rm -rf UserConfigAgentPlugin.bundle
	rm -rf ../build
