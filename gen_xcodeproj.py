#!/usr/bin/env python3
"""Generate PixelPigskin.xcodeproj/project.pbxproj (Xcode 15+ format).

Scans PixelPigskin/ for .swift files and emits a minimal but complete
project: one app target, Sources + Resources phases, Debug/Release configs.
Run from the repo root:  python3 gen_xcodeproj.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(ROOT, "PixelPigskin")
PROJDIR = os.path.join(ROOT, "PixelPigskin.xcodeproj")

APP = "PixelPigskin"
BUNDLE = "com.pixelpigskin.game"

def uid(prefix: str, n: int) -> str:
    # 24-hex-char deterministic IDs, readable prefixes.
    return f"{prefix}{n:020d}"[:24]

def main() -> None:
    swift_files = []
    for dirpath, _dirs, files in os.walk(SRC):
        for f in sorted(files):
            if f.endswith(".swift"):
                full = os.path.join(dirpath, f)
                rel = os.path.relpath(full, ROOT)  # PixelPigskin/App/...
                swift_files.append(rel)
    swift_files.sort()
    if not swift_files:
        print("no swift files found", file=sys.stderr)
        sys.exit(1)
    print(f"including {len(swift_files)} swift files")

    # ID allocation
    file_refs = [uid("F", i) for i in range(len(swift_files))]
    build_files = [uid("B", i) for i in range(len(swift_files))]

    P = []  # build file section lines
    F = []  # file reference lines
    S = []  # sources build phase entries
    G = []  # group children entries
    for i, rel in enumerate(swift_files):
        name = os.path.basename(rel)
        F.append(f'\t\t{file_refs[i]} /* {name} */ = {{isa = PBXFileReference; fileEncoding = 4; lastKnownFileType = sourcecode.swift; path = "{rel}"; sourceTree = "<group>"; }};')
        P.append(f'\t\t{build_files[i]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[i]} /* {name} */; }};')
        S.append(f'\t\t\t\t{build_files[i]} /* {name} in Sources */,')
        G.append(f'\t\t\t\t{file_refs[i]} /* {name} */,')

    app_ref = uid("R", 1)
    main_group = uid("G", 1)
    products_group = uid("G", 2)
    app_group = uid("G", 3)
    sources_phase = uid("H", 1)
    frameworks_phase = uid("H", 2)
    resources_phase = uid("H", 3)
    target = uid("T", 1)
    proj = uid("P", 1)
    proj_cfg_list = uid("C", 1)
    tgt_cfg_list = uid("C", 2)
    proj_dbg = uid("C", 3)
    proj_rel = uid("C", 4)
    tgt_dbg = uid("C", 5)
    tgt_rel = uid("C", 6)

    common_settings = """\
\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;
\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu11;
\t\t\t\tSDKROOT = iphoneos;"""

    proj_debug = f"""\
\t\t{proj_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_settings}
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = dwarf;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGCC_OPTIMIZATION_LEVEL = 0;
\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = (
\t\t\t\t\t"DEBUG=1",
\t\t\t\t\t"$(inherited)",
\t\t\t\t);
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tONLY_ACTIVE_ARCH = YES;
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""
    proj_release = f"""\
\t\t{proj_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_settings}
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_NS_ASSERTIONS = NO;
\t\t\t\tMTL_FAST_MATH = YES;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tVALIDATE_PRODUCT = YES;
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

    tgt_debug = f"""\
\t\t{tgt_dbg} /* Debug */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tENABLE_TESTABILITY = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = {APP};
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-Onone";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Debug;
\t\t}};"""
    tgt_release = f"""\
\t\t{tgt_rel} /* Release */ = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCOPY_PHASE_STRIP = NO;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tDEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
\t\t\t\tENABLE_PREVIEWS = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = {APP};
\t\t\t\tINFOPLIST_KEY_LSRequiresIPhoneOS = YES;
\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;
\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations = "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 26.0;
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/Frameworks",
\t\t\t\t);
\t\t\t\tMARKETING_VERSION = 0.1.0;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = {BUNDLE};
\t\t\t\tPRODUCT_NAME = "$(TARGET_NAME)";
\t\t\t\tSDKROOT = iphoneos;
\t\t\t\tSWIFT_COMPILATION_MODE = wholemodule;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = "-O";
\t\t\t\tSWIFT_VERSION = 5.0;
\t\t\t\tTARGETED_DEVICE_FAMILY = "1,2";
\t\t\t}};
\t\t\tname = Release;
\t\t}};"""

    pbxproj = f"""\
// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 56;
\tobjects = {{

/* Begin PBXBuildFile section */
{chr(10).join(P)}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
\t\t{app_ref} /* {APP}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {APP}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
{chr(10).join(F)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{frameworks_phase} /* Frameworks */ = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{main_group} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_group} /* {APP} */,
\t\t\t\t{products_group} /* Products */,
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{products_group} /* Products */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{app_ref} /* {APP}.app */,
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{app_group} /* {APP} */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{chr(10).join(G)}
\t\t\t);
\t\t\tpath = {APP};
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{target} /* {APP} */ = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {tgt_cfg_list} /* Build configuration list for PBXNativeTarget "{APP}" */;
\t\t\tbuildPhases = (
\t\t\t\t{sources_phase} /* Sources */,
\t\t\t\t{frameworks_phase} /* Frameworks */,
\t\t\t\t{resources_phase} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = {APP};
\t\t\tproductName = {APP};
\t\t\tproductReference = {app_ref} /* {APP}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{proj} /* Project object */ = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1700;
\t\t\t\tLastUpgradeCheck = 1700;
\t\t\t}};
\t\t\tbuildConfigurationList = {proj_cfg_list} /* Build configuration list for PBXProject "{APP}" */;
\t\t\tcompatibilityVersion = "Xcode 15.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = {main_group};
\t\t\tproductRefGroup = {products_group} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{target} /* {APP} */,
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{resources_phase} /* Resources */ = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{sources_phase} /* Sources */ = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
{chr(10).join(S)}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
{proj_debug}
{proj_release}
{tgt_debug}
{tgt_release}
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{proj_cfg_list} /* Build configuration list for PBXProject "{APP}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{proj_dbg} /* Debug */,
\t\t\t\t{proj_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{tgt_cfg_list} /* Build configuration list for PBXNativeTarget "{APP}" */ = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t{tgt_dbg} /* Debug */,
\t\t\t\t{tgt_rel} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

\t}};
\trootObject = {proj} /* Project object */;
}}
"""
    os.makedirs(PROJDIR, exist_ok=True)
    with open(os.path.join(PROJDIR, "project.pbxproj"), "w") as f:
        f.write(pbxproj)
    print(f"wrote {PROJDIR}/project.pbxproj")

if __name__ == "__main__":
    main()
