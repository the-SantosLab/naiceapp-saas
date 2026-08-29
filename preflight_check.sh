#!/usr/bin/env bash
# nAIce Pre-Flight Check - Läuft vor jedem Build/Deploy
# Checkt ob alle iOS-Projektdateien korrekt sind

set -e
PROJECT_DIR="/Users/johannesschaffer/Desktop/naiceapp-fresh"
EXIT_CODE=0

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[1;33m'
cyan='\033[0;36m'
nc='\033[0m'

echo -e "${cyan}═══════════════════════════════════════${nc}"
echo -e "${cyan}  nAIce Pre-Flight Check${nc}"
echo -e "${cyan}═══════════════════════════════════════${nc}"

# 1. Check Info.plist
PLIST="${PROJECT_DIR}/HermesMobile/Resources/Info.plist"
echo -e "\n${cyan}📋 Info.plist:${nc}"
for key in "NSSupportsLiveActivities" "CFBundleURLTypes" "NSFaceIDUsageDescription" "NSSiriUsageDescription" "NSHealthShareUsageDescription"; do
    if grep -q "$key" "$PLIST" 2>/dev/null; then
        echo -e "  ${green}✅${nc} $key"
    else
        echo -e "  ${red}❌${nc} $key fehlt!"
        EXIT_CODE=1
    fi
done

# 2. Check Entitlements
ENT="${PROJECT_DIR}/HermesMobile/Resources/HermesMobile.entitlements"
echo -e "\n${cyan}📋 Entitlements:${nc}"
for key in "aps-environment" "com.apple.developer.siri" "com.apple.developer.homekit"; do
    if grep -q "$key" "$ENT" 2>/dev/null; then
        echo -e "  ${green}✅${nc} $key"
    else
        echo -e "  ${yellow}⚠️${nc} $key fehlt (optional)"
    fi
done

# 3. Check pbxproj SystemCapabilities
PBX="${PROJECT_DIR}/HermesMobile.xcodeproj/project.pbxproj"
echo -e "\n${cyan}📋 pbxproj SystemCapabilities:${nc}"
for cap in "com.apple.Siri" "com.apple.HomeKit"; do
    if grep -q "$cap" "$PBX" 2>/dev/null; then
        echo -e "  ${green}✅${nc} $cap"
    else
        echo -e "  ${red}❌${nc} $cap fehlt in SystemCapabilities!"
        EXIT_CODE=1
    fi
done

# 4. Check import urllib shadowing (known bug)
AGENT_PY="/opt/naice_agent.py"
if [ -f "$AGENT_PY" ]; then
    if grep -n "import urllib.request" "$AGENT_PY" | grep -v "^3:" > /dev/null; then
        echo -e "\n  ${red}❌${nc} Shadowing import urllib.request in naice_agent.py! (bekannter Bug)"
        echo -e "  ${yellow}💡${nc} Nur Zeile 3 darf import urllib.request haben"
        EXIT_CODE=1
    fi
fi

# 5. Check Xcode project references
echo -e "\n${cyan}📋 Xcode Projekt:${nc}"
if ls "${PROJECT_DIR}/HermesMobile.xcodeproj" >/dev/null 2>&1; then
    echo -e "  ${green}✅${nc} Xcode project existiert"
else
    echo -e "  ${red}❌${nc} Xcode project fehlt!"
    EXIT_CODE=1
fi

# Final verdict
echo -e "\n${cyan}═══════════════════════════════════════${nc}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${green}  ✅ PRE-FLIGHT PASSED${nc}"
else
    echo -e "${red}  ❌ PRE-FLIGHT FAILED - Behebe die Fehler vor dem Build${nc}"
fi
echo -e "${cyan}═══════════════════════════════════════${nc}"
exit $EXIT_CODE