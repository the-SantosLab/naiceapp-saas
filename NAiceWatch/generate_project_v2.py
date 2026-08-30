#!/usr/bin/env python3
import hashlib, os

WATCH_DIR = '/Users/johannesschaffer/Desktop/naiceapp-fresh/NAiceWatch'
PBX_PATH = WATCH_DIR + '/NAiceWatch.xcodeproj/project.pbxproj'

def md5(s):
    return hashlib.md5(s.encode()).hexdigest()[:24].upper()

existing = set()
def nid(seed):
    for i in range(1000):
        h = md5(seed + str(i))
        if h not in existing:
            existing.add(h)
            return h
    raise RuntimeError("no id")

ID = {}
for name in ['ROOT', 'PROD_GRP', 'MAIN_GRP', 'VIEWS_GRP', 'COMPL_GRP', 'CONN_GRP', 'PROJ', 'TGT', 'PROD', 'DBG', 'REL', 'CL', 'SRC', 'RES', 'FW']:
    ID[name] = nid(name)

swift_files = []
for root, dirs, fnames in os.walk(WATCH_DIR):
    for f in fnames:
        if f.endswith('.swift'):
            swift_files.append(os.path.relpath(os.path.join(root, f), WATCH_DIR))

sfid = {s: nid('sf'+s) for s in swift_files}
bfid = {s: nid('bf'+s) for s in swift_files}

lines = []
lines.append('// !$*UTF8*$!')
lines.append('{')
lines.append('\tarchiveVersion = 1;')
lines.append('\tclasses = {')
lines.append('\t};')
lines.append('\tobjectVersion = 56;')
lines.append('\tobjects = {')

# PBXBuildFile
lines.append('')
lines.append('/* Begin PBXBuildFile section */')
for s in swift_files:
    bn = os.path.basename(s)
    lines.append(f'\t\t{bfid[s]} /* {bn} in Sources */ = {{isa = PBXBuildFile; fileRef = {sfid[s]}; }};')
lines.append('/* End PBXBuildFile section */')

# PBXFileReference
lines.append('')
lines.append('/* Begin PBXFileReference section */')
lines.append(f'\t\t{ID["PROD"]} /* NAiceWatch.app */ = {{isa = PBXFileReference; explicitFileType = "wrapper.application"; includeInIndex = 0; path = NAiceWatch.app; sourceTree = BUILT_PRODUCTS_DIR; }};')
for s in swift_files:
    bn = os.path.basename(s)
    lines.append(f'\t\t{sfid[s]} /* {bn} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{s}"; sourceTree = SOURCE_ROOT; }};')
lines.append('/* End PBXFileReference section */')

# Frameworks
lines.append('')
lines.append('/* Begin PBXFrameworksBuildPhase section */')
lines.append(f'\t\t{ID["FW"]} /* Frameworks */ = {{')
lines.append('\t\t\tisa = PBXFrameworksBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXFrameworksBuildPhase section */')

# Groups
lines.append('')
lines.append('/* Begin PBXGroup section */')
for gid, gname in [(ID['VIEWS_GRP'], 'Views'), (ID['COMPL_GRP'], 'Complication'), (ID['CONN_GRP'], 'Connectivity')]:
    lines.append(f'\t\t{gid} /* {gname} */ = {{')
    lines.append('\t\t\tisa = PBXGroup;')
    lines.append('\t\t\tchildren = (')
    for s in swift_files:
        if s.startswith(gname + '/'):
            lines.append(f'\t\t\t\t{sfid[s]} /* {os.path.basename(s)} */,')
    lines.append('\t\t\t);')
    lines.append(f'\t\t\tpath = {gname};')
    lines.append('\t\t\tsourceTree = SOURCE_ROOT;')
    lines.append('\t\t};')

lines.append(f'\t\t{ID["MAIN_GRP"]} /* NAiceWatch */ = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f'\t\t\t\t{ID["VIEWS_GRP"]} /* Views */,')
lines.append(f'\t\t\t\t{ID["COMPL_GRP"]} /* Complication */,')
lines.append(f'\t\t\t\t{ID["CONN_GRP"]} /* Connectivity */,')
for s in swift_files:
    if '/' not in s:
        lines.append(f'\t\t\t\t{sfid[s]} /* {os.path.basename(s)} */,')
lines.append('\t\t\t);')
lines.append('\t\t\tpath = "";')
lines.append('\t\t\tsourceTree = SOURCE_ROOT;')
lines.append('\t\t};')

lines.append(f'\t\t{ID["PROD_GRP"]} /* Products */ = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f'\t\t\t\t{ID["PROD"]} /* NAiceWatch.app */,')
lines.append('\t\t\t);')
lines.append('\t\t\tname = Products;')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')

lines.append(f'\t\t{ID["ROOT"]} = {{')
lines.append('\t\t\tisa = PBXGroup;')
lines.append('\t\t\tchildren = (')
lines.append(f'\t\t\t\t{ID["MAIN_GRP"]} /* NAiceWatch */,')
lines.append(f'\t\t\t\t{ID["PROD_GRP"]} /* Products */,')
lines.append('\t\t\t);')
lines.append('\t\t\tsourceTree = "<group>";')
lines.append('\t\t};')
lines.append('/* End PBXGroup section */')

# Native target
lines.append('')
lines.append('/* Begin PBXNativeTarget section */')
lines.append(f'\t\t{ID["TGT"]} /* NAiceWatch */ = {{')
lines.append('\t\t\tisa = PBXNativeTarget;')
lines.append(f'\t\t\tbuildConfigurationList = {ID["CL"]};')
lines.append('\t\t\tbuildPhases = (')
lines.append(f'\t\t\t\t{ID["SRC"]} /* Sources */,')
lines.append(f'\t\t\t\t{ID["FW"]} /* Frameworks */,')
lines.append(f'\t\t\t\t{ID["RES"]} /* Resources */,')
lines.append('\t\t\t);')
lines.append('\t\t\tbuildRules = (')
lines.append('\t\t\t);')
lines.append('\t\t\tdependencies = (')
lines.append('\t\t\t);')
lines.append('\t\t\tname = NAiceWatch;')
lines.append('\t\t\tproductName = NAiceWatch;')
lines.append(f'\t\t\tproductReference = {ID["PROD"]};')
lines.append('\t\t\tproductType = "com.apple.product-type.application.watchapp2";')
lines.append('\t\t};')
lines.append('/* End PBXNativeTarget section */')

# Project
lines.append('')
lines.append('/* Begin PBXProject section */')
lines.append(f'\t\t{ID["PROJ"]} /* Project object */ = {{')
lines.append('\t\t\tisa = PBXProject;')
lines.append('\t\t\tattributes = {')
lines.append('\t\t\t\tBuildIndependentTargetsInParallel = 1;')
lines.append('\t\t\t\tLastSwiftUpdateCheck = 1600;')
lines.append('\t\t\t\tLastUpgradeCheck = 1600;')
lines.append('\t\t\t};')
lines.append(f'\t\t\tbuildConfigurationList = {ID["CL"]};')
lines.append('\t\t\tcompatibilityVersion = "Xcode 14.0";')
lines.append('\t\t\tdevelopmentRegion = en;')
lines.append('\t\t\thasScannedForEncodings = 0;')
lines.append('\t\t\tknownRegions = (')
lines.append('\t\t\t\ten,')
lines.append('\t\t\t);')
lines.append(f'\t\t\tmainGroup = {ID["ROOT"]};')
lines.append(f'\t\t\tproductRefGroup = {ID["PROD_GRP"]};')
lines.append('\t\t\tprojectDirPath = "";')
lines.append('\t\t\tprojectRoot = "";')
lines.append('\t\t\ttargets = (')
lines.append(f'\t\t\t\t{ID["TGT"]} /* NAiceWatch */,')
lines.append('\t\t\t);')
lines.append('\t\t};')
lines.append('/* End PBXProject section */')

# Resources
lines.append('')
lines.append('/* Begin PBXResourcesBuildPhase section */')
lines.append(f'\t\t{ID["RES"]} /* Resources */ = {{')
lines.append('\t\t\tisa = PBXResourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXResourcesBuildPhase section */')

# Sources
lines.append('')
lines.append('/* Begin PBXSourcesBuildPhase section */')
lines.append(f'\t\t{ID["SRC"]} /* Sources */ = {{')
lines.append('\t\t\tisa = PBXSourcesBuildPhase;')
lines.append('\t\t\tbuildActionMask = 2147483647;')
lines.append('\t\t\tfiles = (')
for s in swift_files:
    lines.append(f'\t\t\t\t{bfid[s]} /* {os.path.basename(s)} in Sources */,')
lines.append('\t\t\t);')
lines.append('\t\t\trunOnlyForDeploymentPostprocessing = 0;')
lines.append('\t\t};')
lines.append('/* End PBXSourcesBuildPhase section */')

# Build configs - KEY FIX: DEPLOYMENT_POSTPROCESSING must be NO to avoid CopyAndPreserveArchs
shared_bs = (
    '\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;\n'
    '\t\t\t\tCODE_SIGN_STYLE = Automatic;\n'
    '\t\t\t\tCURRENT_PROJECT_VERSION = 1;\n'
    '\t\t\t\tDEPLOYMENT_POSTPROCESSING = NO;\n'
    '\t\t\t\tDEVELOPMENT_TEAM = GX89CS2T99;\n'
    '\t\t\t\tINFOPLIST_FILE = "NAiceWatch/Resources/Info.plist";\n'
    '\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (\n'
    '\t\t\t\t\t"$(inherited)",\n'
    '\t\t\t\t\t"@executable_path/Frameworks",\n'
    '\t\t\t\t);\n'
    '\t\t\t\tMARKETING_VERSION = 1.5;\n'
    '\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = pro.naice.app.watchkitapp;\n'
    '\t\t\t\tPRODUCT_NAME = NAiceWatch;\n'
    '\t\t\t\tSDKROOT = watchos;\n'
    '\t\t\t\tSKIP_INSTALL = YES;\n'
    '\t\t\t\tSWIFT_VERSION = 5.0;\n'
    '\t\t\t\tTARGETED_DEVICE_FAMILY = 4;\n'
)

lines.append('')
lines.append('/* Begin XCBuildConfiguration section */')
for cname, cid in [('Debug', ID['DBG']), ('Release', ID['REL'])]:
    lines.append(f'\t\t{cid} /* {cname} */ = {{')
    lines.append('\t\t\tisa = XCBuildConfiguration;')
    lines.append('\t\t\tbuildSettings = {')
    for b in shared_bs.rstrip('\n').split('\n'):
        lines.append(b)
    lines.append('\t\t\t};')
    lines.append(f'\t\t\tname = {cname};')
    lines.append('\t\t};')
lines.append('/* End XCBuildConfiguration section */')

# Config list
lines.append('')
lines.append('/* Begin XCConfigurationList section */')
lines.append(f'\t\t{ID["CL"]} = {{')
lines.append('\t\t\tisa = XCConfigurationList;')
lines.append('\t\t\tbuildConfigurations = (')
lines.append(f'\t\t\t\t{ID["DBG"]} /* Debug */,')
lines.append(f'\t\t\t\t{ID["REL"]} /* Release */,')
lines.append('\t\t\t);')
lines.append('\t\t\tdefaultConfigurationIsVisible = 0;')
lines.append('\t\t\tdefaultConfigurationName = Release;')
lines.append('\t\t};')
lines.append('/* End XCConfigurationList section */')

lines.append('\t};')
lines.append(f'\trootObject = {ID["PROJ"]};')
lines.append('}')

with open(PBX_PATH, 'w') as f:
    f.write('\n'.join(lines))

print(f"✅ Regenerated with DEPLOYMENT_POSTPROCESSING = NO")