#!/usr/bin/env python3
"""Generate the native iOS project and its local DarjaF5 package dependency.

The same Sources/DarjaCore files are compiled directly into the iOS target and
tested independently by Swift Package Manager. UI files should import DarjaCore
only inside #if canImport(DarjaCore).
"""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
NAME = "DarjaTogether"
objects = {}


def uid(value):
    return hashlib.sha256(value.encode()).hexdigest()[:24].upper()


def quote(value):
    return json.dumps(str(value))


def add(key, body):
    identifier = uid(key)
    objects[identifier] = body
    return identifier


def array(values):
    return "( " + ", ".join(values) + (", " if values else "") + ")"


def settings(values):
    return "{ " + " ".join(f"{key} = {quote(value)};" for key, value in values.items()) + " }"


sources = sorted(
    path.relative_to(ROOT).as_posix()
    for folder in (ROOT / NAME, ROOT / "Sources/DarjaCore")
    for path in folder.rglob("*.swift")
)
ui_sources = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "UITests").rglob("*.swift"))
smoke_sources = sorted(path.relative_to(ROOT).as_posix() for path in (ROOT / "Packages/DarjaF5/Sources/DarjaF5Smoke").rglob("*.swift"))
if not sources:
    raise SystemExit("No Swift sources found. Run this from the complete DarjaTogether source tree.")

resources = []
assets = ROOT / NAME / "Assets.xcassets"
if assets.exists():
    resources.append(f"{NAME}/Assets.xcassets")
resource_directory = ROOT / NAME / "Resources"
if resource_directory.exists():
    # Model assets must keep their directory structure. Individual PBX resource
    # entries would flatten config/weights or split a compiled model package.
    def collect_resources(directory):
        for path in sorted(directory.iterdir()):
            if path.name.startswith(".") or path.name == "schema.json":
                continue
            if path.is_dir() and (path.name == "SpeechModel" or path.suffix in {".mlmodelc", ".mlpackage", ".bundle"}):
                yield path.relative_to(ROOT).as_posix()
            elif path.is_dir():
                yield from collect_resources(path)
            elif path.is_file():
                yield path.relative_to(ROOT).as_posix()
    resources.extend(collect_resources(resource_directory))
resources.append(f"{NAME}/PrivacyInfo.xcprivacy")
references, source_builds, resource_builds, ui_builds, smoke_builds = [], [], [], [], []
for path in sources + resources + ui_sources + smoke_sources:
    suffix = Path(path).suffix
    kind = "folder" if (ROOT / path).is_dir() and suffix != ".xcassets" else {
        ".swift": "sourcecode.swift",
        ".xcassets": "folder.assetcatalog",
        ".json": "text.json",
        ".xcprivacy": "text.xml",
        ".png": "image.png",
        ".jpg": "image.jpeg",
        ".wav": "audio.wav",
        ".mp3": "audio.mp3",
    }.get(suffix, "file")
    reference = add("reference:" + path, f'isa = PBXFileReference; lastKnownFileType = {quote(kind)}; path = {quote(path)}; sourceTree = "<group>";')
    build = add("build:" + path, f"isa = PBXBuildFile; fileRef = {reference};")
    references.append(reference)
    (source_builds if path in sources else ui_builds if path in ui_sources else smoke_builds if path in smoke_sources else resource_builds).append(build)

info_reference = add("info", f'isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = "{NAME}/Info.plist"; sourceTree = "<group>";')
product = add("product", f'isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {NAME}.app; sourceTree = BUILT_PRODUCTS_DIR;')
ui_name = f"{NAME}UITests"
ui_product = add("ui_product", f'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = {ui_name}.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
smoke_name = "DarjaF5Smoke"
smoke_product = add("smoke_product", f'isa = PBXFileReference; explicitFileType = "compiled.mach-o.executable"; includeInIndex = 0; path = {smoke_name}; sourceTree = BUILT_PRODUCTS_DIR;')
products = add("products", f'isa = PBXGroup; name = Products; children = {array([product, ui_product, smoke_product])}; sourceTree = "<group>";')
main = add("main", f'isa = PBXGroup; children = {array(references + [info_reference, products])}; sourceTree = "<group>";')
source_phase = add("sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(source_builds)}; runOnlyForDeploymentPostprocessing = 0;")
resource_phase = add("resources", f"isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {array(resource_builds)}; runOnlyForDeploymentPostprocessing = 0;")
framework_phase = add("frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
# This package is intentionally separate from Package.swift's Foundation-only
# learning tests. Xcode owns resolution and compilation of MLX's Metal assets.
speech_package = add("package:DarjaF5", 'isa = XCLocalSwiftPackageReference; relativePath = "Packages/DarjaF5";')
speech_product = add("package_product:DarjaF5", f'isa = XCSwiftPackageProductDependency; package = {speech_package}; productName = DarjaF5;')
speech_build = add("package_build:DarjaF5", f"isa = PBXBuildFile; productRef = {speech_product};")
objects[framework_phase] = f"isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {array([speech_build])}; runOnlyForDeploymentPostprocessing = 0;"
# The command-line driver imports MLX directly for explicit CPU/GPU selection.
# Match the local library's exact version, rather than relying on visibility of
# transitive Swift modules or selecting a newer incompatible runtime.
mlx_package = add("package:MLX", 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/ml-explore/mlx-swift"; requirement = { kind = exactVersion; version = "0.21.2"; };')
mlx_product = add("package_product:MLX", f"isa = XCSwiftPackageProductDependency; package = {mlx_package}; productName = MLX;")
mlx_smoke_build = add("package_build:MLXSmoke", f"isa = PBXBuildFile; productRef = {mlx_product};")
ui_source_phase = add("ui_sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(ui_builds)}; runOnlyForDeploymentPostprocessing = 0;")
ui_framework_phase = add("ui_frameworks", "isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;")
smoke_source_phase = add("smoke_sources", f"isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {array(smoke_builds)}; runOnlyForDeploymentPostprocessing = 0;")
smoke_speech_build = add("package_build:DarjaF5Smoke", f"isa = PBXBuildFile; productRef = {speech_product};")
smoke_framework_phase = add("smoke_frameworks", f"isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {array([smoke_speech_build, mlx_smoke_build])}; runOnlyForDeploymentPostprocessing = 0;")
project_configs, target_configs, ui_configs, smoke_configs = [], [], [], []
for configuration in ("Debug", "Release"):
    debug = configuration == "Debug"
    common = {
        "ALWAYS_SEARCH_USER_PATHS": "NO",
        "CLANG_ENABLE_MODULES": "YES",
        "CLANG_ENABLE_OBJC_ARC": "YES",
        "CLANG_WARN_UNREACHABLE_CODE": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
        "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0",
        "DEBUG_INFORMATION_FORMAT": "dwarf" if debug else "dwarf-with-dsym",
        "SWIFT_OPTIMIZATION_LEVEL": "-Onone" if debug else "-O",
        "ENABLE_TESTABILITY": "YES" if debug else "NO",
        "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG" if debug else "",
    }
    target = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "CODE_SIGN_STYLE": "Automatic",
        "CURRENT_PROJECT_VERSION": "2",
        "MARKETING_VERSION": "1.1",
        "GENERATE_INFOPLIST_FILE": "NO",
        "INFOPLIST_FILE": f"{NAME}/Info.plist",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.darjatogether.learn",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "SUPPORTS_MACCATALYST": "NO",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks",
        "ENABLE_PREVIEWS": "YES",
        "SWIFT_EMIT_LOC_STRINGS": "YES",
    }
    project_configs.append(add("project_config:" + configuration, f"isa = XCBuildConfiguration; buildSettings = {settings(common)}; name = {configuration};"))
    target_configs.append(add("target_config:" + configuration, f"isa = XCBuildConfiguration; buildSettings = {settings(target)}; name = {configuration};"))

    ui_settings = {
        "CODE_SIGN_STYLE": "Automatic",
        "GENERATE_INFOPLIST_FILE": "YES",
        "PRODUCT_BUNDLE_IDENTIFIER": "com.darjatogether.learn.uitests",
        "PRODUCT_NAME": "$(TARGET_NAME)",
        "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "TARGETED_DEVICE_FAMILY": "1,2",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @loader_path/Frameworks",
        "TEST_TARGET_NAME": NAME,
        "SWIFT_EMIT_LOC_STRINGS": "NO",
    }
    ui_configs.append(add("ui_config:" + configuration, f"isa = XCBuildConfiguration; buildSettings = {settings(ui_settings)}; name = {configuration};"))
    smoke_settings = {
        "SDKROOT": "macosx",
        "SUPPORTED_PLATFORMS": "macosx",
        "MACOSX_DEPLOYMENT_TARGET": "14.0",
        "PRODUCT_NAME": smoke_name,
        "PRODUCT_BUNDLE_IDENTIFIER": "com.darjatogether.speech-smoke",
        "CODE_SIGN_STYLE": "Automatic",
        "OTHER_SWIFT_FLAGS": "$(inherited) -parse-as-library",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/PackageFrameworks @executable_path",
    }
    smoke_configs.append(add("smoke_config:" + configuration, f"isa = XCBuildConfiguration; buildSettings = {settings(smoke_settings)}; name = {configuration};"))

project_config_list = add("project_config_list", f"isa = XCConfigurationList; buildConfigurations = {array(project_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target_config_list = add("target_config_list", f"isa = XCConfigurationList; buildConfigurations = {array(target_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
target = add("target", f'isa = PBXNativeTarget; buildConfigurationList = {target_config_list}; buildPhases = {array([source_phase, framework_phase, resource_phase])}; buildRules = (); dependencies = (); packageProductDependencies = {array([speech_product])}; name = {NAME}; productName = {NAME}; productReference = {product}; productType = "com.apple.product-type.application";')
ui_config_list = add("ui_config_list", f"isa = XCConfigurationList; buildConfigurations = {array(ui_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
ui_proxy = add("ui_proxy", f"isa = PBXContainerItemProxy; containerPortal = {uid('project')}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = {NAME};")
ui_dependency = add("ui_dependency", f"isa = PBXTargetDependency; target = {target}; targetProxy = {ui_proxy};")
ui_target = add("ui_target", f'isa = PBXNativeTarget; buildConfigurationList = {ui_config_list}; buildPhases = {array([ui_source_phase, ui_framework_phase])}; buildRules = (); dependencies = {array([ui_dependency])}; name = {ui_name}; productName = {ui_name}; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";')
smoke_config_list = add("smoke_config_list", f"isa = XCConfigurationList; buildConfigurations = {array(smoke_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;")
smoke_target = add("smoke_target", f'isa = PBXNativeTarget; buildConfigurationList = {smoke_config_list}; buildPhases = {array([smoke_source_phase, smoke_framework_phase])}; buildRules = (); dependencies = (); packageProductDependencies = {array([speech_product, mlx_product])}; name = {smoke_name}; productName = {smoke_name}; productReference = {smoke_product}; productType = "com.apple.product-type.tool";')
project = add("project", f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1640; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.4; }}; {ui_target} = {{ CreatedOnToolsVersion = 16.4; TestTargetID = {target}; }}; }}; }}; buildConfigurationList = {project_config_list}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; packageReferences = {array([speech_package, mlx_package])}; projectDirPath = ""; projectRoot = ""; targets = {array([target, ui_target, smoke_target])};')

project_directory = ROOT / f"{NAME}.xcodeproj"
project_directory.mkdir(exist_ok=True)
(project_directory / "project.pbxproj").write_text(
    "// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n"
    + "".join(f"  {identifier} = {{ {body} }};\n" for identifier, body in objects.items())
    + f" }};\n rootObject = {project};\n}}\n", encoding="utf-8"
)
scheme_directory = project_directory / "xcshareddata/xcschemes"
scheme_directory.mkdir(parents=True, exist_ok=True)
reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{NAME}.app" BlueprintName="{NAME}" ReferencedContainer="container:{NAME}.xcodeproj"/>'
ui_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="{ui_name}.xctest" BlueprintName="{ui_name}" ReferencedContainer="container:{NAME}.xcodeproj"/>'
(scheme_directory / f"{NAME}.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO" parallelizable="NO">{ui_reference}</TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{reference}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/>
 <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
''', encoding="utf-8")
smoke_reference = f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{smoke_target}" BuildableName="{smoke_name}" BlueprintName="{smoke_name}" ReferencedContainer="container:{NAME}.xcodeproj"/>'
(scheme_directory / f"{smoke_name}.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="NO" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="NO" buildForAnalyzing="YES">{smoke_reference}</BuildActionEntry></BuildActionEntries></BuildAction>
 <LaunchAction buildConfiguration="Release" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO"><BuildableProductRunnable runnableDebuggingMode="0">{smoke_reference}</BuildableProductRunnable></LaunchAction>
 <AnalyzeAction buildConfiguration="Release"/>
</Scheme>
''', encoding="utf-8")

privacy = {
    "NSPrivacyTracking": False,
    "NSPrivacyTrackingDomains": [],
    "NSPrivacyCollectedDataTypes": [],
    "NSPrivacyAccessedAPITypes": [],
}
(ROOT / NAME / "PrivacyInfo.xcprivacy").write_bytes(plistlib.dumps(privacy))
print(f"Generated {NAME}.xcodeproj: {len(sources)} app Swift files, {len(ui_sources)} UI test files, {len(resources)} resources.")
