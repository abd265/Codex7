#!/usr/bin/env python3
"""Regenerate the checked-in Xcode project with a pinned official Supabase Auth SDK."""
from pathlib import Path
import hashlib,json,plistlib
ROOT=Path(__file__).resolve().parents[1]
def uid(s):return hashlib.sha256(s.encode()).hexdigest()[:24].upper()
def q(s):return json.dumps(str(s))
objects={}
def add(key,body):objects[uid(key)]=body;return uid(key)
source_paths=sorted([p.relative_to(ROOT).as_posix() for p in (ROOT/'RiseBake').glob('*.swift')]+[p.relative_to(ROOT).as_posix() for p in (ROOT/'Sources/RiseBakeCore').glob('*.swift')])
resources=['RiseBake/Assets.xcassets','RiseBake/Resources/seed.json','RiseBake/PrivacyInfo.xcprivacy','RiseBake/Resources/AuthConfig.json','RiseBake/Resources/MembershipConfig.json']
refs=[];srcs=[];res=[]
for path in source_paths+resources:
 typ='sourcecode.swift' if path.endswith('.swift') else 'folder.assetcatalog' if path.endswith('.xcassets') else 'text.json' if path.endswith('.json') else 'text.xml'
 ref=add('ref:'+path,f'isa = PBXFileReference; lastKnownFileType = {q(typ)}; path = {q(path)}; sourceTree = "<group>";')
 build=add('build:'+path,f'isa = PBXBuildFile; fileRef = {ref};')
 refs.append(ref);(srcs if path in source_paths else res).append(build)
def arr(xs):return '( '+', '.join(xs)+', )'
product=add('product','isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = RiseBake.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=add('products',f'isa = PBXGroup; name = Products; children = {arr([product])}; sourceTree = "<group>";')
ui_ref=add('uitest-ref', 'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "UITests/RiseBakeUITests.swift"; sourceTree = "<group>";')
refs.append(ui_ref)
storekit_ref=add('storekit-ref', 'isa = PBXFileReference; lastKnownFileType = text; path = "UITests/RiseBakePlans.storekit"; sourceTree = "<group>";')
refs.append(storekit_ref)
storekit_build=add('storekit-build',f'isa = PBXBuildFile; fileRef = {storekit_ref};')
ui_resources=add('uitest-resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ( {storekit_build}, ); runOnlyForDeploymentPostprocessing = 0;')
main=add('main',f'isa = PBXGroup; children = {arr(refs+[products])}; sourceTree = "<group>";')
sources=add('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(srcs)}; runOnlyForDeploymentPostprocessing = 0;')
resource=add('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = {arr(res)}; runOnlyForDeploymentPostprocessing = 0;')
auth_package=add('auth-package', 'isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/supabase/supabase-swift.git"; requirement = { kind = exactVersion; version = 2.55.2; };')
auth_product=add('auth-product', f'isa = XCSwiftPackageProductDependency; package = {auth_package}; productName = Auth;')
auth_build=add('auth-build', f'isa = PBXBuildFile; productRef = {auth_product};')
frameworks=add('frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = {arr([auth_build])}; runOnlyForDeploymentPostprocessing = 0;')
projconfigs=[];targetconfigs=[]
for config in ['Debug','Release']:
 common={'ALWAYS_SEARCH_USER_PATHS':'NO','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','DEBUG_INFORMATION_FORMAT':'dwarf' if config=='Debug' else 'dwarf-with-dsym','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if config=='Debug' else '-O','ENABLE_TESTABILITY':'YES' if config=='Debug' else 'NO','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG' if config=='Debug' else ''}
 target={'ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME':'AccentColor','CODE_SIGN_STYLE':'Automatic','CURRENT_PROJECT_VERSION':'26','MARKETING_VERSION':'2.4','INFOPLIST_FILE':'RiseBake/Info.plist','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'Rise & Bake','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.business','INFOPLIST_KEY_UIApplicationSceneManifest_Generation':'YES','INFOPLIST_KEY_UILaunchScreen_Generation':'YES','INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents':'YES','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone':'UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad':'UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight','PRODUCT_BUNDLE_IDENTIFIER':'com.risebake.preview','PRODUCT_NAME':'$(TARGET_NAME)','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SUPPORTS_MACCATALYST':'NO','TARGETED_DEVICE_FAMILY':'1,2','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks'}
 def settings(d):return '{ '+' '.join(f'{k} = {q(v)};' for k,v in d.items())+' }'
 projconfigs.append(add('pc:'+config,f'isa = XCBuildConfiguration; buildSettings = {settings(common)}; name = {config};'))
 targetconfigs.append(add('tc:'+config,f'isa = XCBuildConfiguration; buildSettings = {settings(target)}; name = {config};'))
pc=add('pcl',f'isa = XCConfigurationList; buildConfigurations = {arr(projconfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
tc=add('tcl',f'isa = XCConfigurationList; buildConfigurations = {arr(targetconfigs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
target=add('target',f'isa = PBXNativeTarget; buildConfigurationList = {tc}; buildPhases = {arr([sources,frameworks,resource])}; buildRules = (); dependencies = (); packageProductDependencies = {arr([auth_product])}; name = RiseBake; productName = RiseBake; productReference = {product}; productType = "com.apple.product-type.application";')
ui_build=add('uitest-build',f'isa = PBXBuildFile; fileRef = {ui_ref};')
ui_sources=add('uitest-sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr([ui_build])}; runOnlyForDeploymentPostprocessing = 0;')
ui_product=add('uitest-product','isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = RiseBakeUITests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
objects[products]=f'isa = PBXGroup; name = Products; children = {arr([product,ui_product])}; sourceTree = "<group>";'
ui_configs=[]
for config in ['Debug','Release']:
 ui_settings={'CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'YES','PRODUCT_BUNDLE_IDENTIFIER':'com.risebake.uitests','PRODUCT_NAME':'$(TARGET_NAME)','TEST_TARGET_NAME':'RiseBake','TARGETED_DEVICE_FAMILY':'1,2'}
 ui_configs.append(add('uic:'+config,f'isa = XCBuildConfiguration; buildSettings = {settings(ui_settings)}; name = {config};'))
ui_configlist=add('uicl',f'isa = XCConfigurationList; buildConfigurations = {arr(ui_configs)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
proxy=add('uitest-proxy',f'isa = PBXContainerItemProxy; containerPortal = {uid("project")}; proxyType = 1; remoteGlobalIDString = {target}; remoteInfo = RiseBake;')
dependency=add('uitest-dependency',f'isa = PBXTargetDependency; target = {target}; targetProxy = {proxy};')
ui_target=add('uitest-target',f'isa = PBXNativeTarget; buildConfigurationList = {ui_configlist}; buildPhases = {arr([ui_sources,ui_resources])}; buildRules = (); dependencies = {arr([dependency])}; name = RiseBakeUITests; productName = RiseBakeUITests; productReference = {ui_product}; productType = "com.apple.product-type.bundle.ui-testing";')
project=add('project',f'isa = PBXProject; attributes = {{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1640; TargetAttributes = {{ {target} = {{ CreatedOnToolsVersion = 16.4; }}; }}; }}; buildConfigurationList = {pc}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {main}; productRefGroup = {products}; packageReferences = {arr([auth_package])}; projectDirPath = ""; projectRoot = ""; targets = {arr([target,ui_target])};')
p=ROOT/'RiseBake.xcodeproj';p.mkdir(exist_ok=True)
(p/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56;\n objects = {\n'+''.join(f'  {id} = {{ {body} }};\n' for id,body in objects.items())+f' }};\n rootObject = {project};\n}}\n')
s=p/'xcshareddata/xcschemes';s.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="RiseBake.app" BlueprintName="RiseBake" ReferencedContainer="container:RiseBake.xcodeproj"/>'
(s/'RiseBake.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1640" version="1.3">
 <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
 <TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ui_target}" BuildableName="RiseBakeUITests.xctest" BlueprintName="RiseBakeUITests" ReferencedContainer="container:RiseBake.xcodeproj"/></TestableReference></Testables></TestAction>
 <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable><StoreKitConfigurationFileReference identifier="../../UITests/RiseBakePlans.storekit"/></LaunchAction>
 <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
 <AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
(ROOT/'RiseBake/Info.plist').write_bytes(plistlib.dumps({'CFBundleURLTypes':[{'CFBundleURLName':'com.risebake.auth','CFBundleURLSchemes':['riseandbake'],'CFBundleTypeRole':'Editor'}]}))
# Enable with a correctly provisioned Apple Developer build, not the free sideload profile.
(ROOT/'RiseBake/AppleSignIn.entitlements').write_bytes(plistlib.dumps({'com.apple.developer.applesignin':['Default']}))
privacy={'NSPrivacyTracking':False,'NSPrivacyTrackingDomains':[],'NSPrivacyCollectedDataTypes':[],'NSPrivacyAccessedAPITypes':[{'NSPrivacyAccessedAPIType':'NSPrivacyAccessedAPICategoryUserDefaults','NSPrivacyAccessedAPITypeReasons':['CA92.1']}]}
auth_config=json.loads((ROOT/'RiseBake/Resources/AuthConfig.json').read_text())
if auth_config.get('enabled'):
 privacy['NSPrivacyCollectedDataTypes']=[{'NSPrivacyCollectedDataType':kind,'NSPrivacyCollectedDataTypeLinked':True,'NSPrivacyCollectedDataTypeTracking':False,'NSPrivacyCollectedDataTypePurposes':['NSPrivacyCollectedDataTypePurposeAppFunctionality']} for kind in ['NSPrivacyCollectedDataTypeEmailAddress','NSPrivacyCollectedDataTypeUserID']]
(ROOT/'RiseBake/PrivacyInfo.xcprivacy').write_bytes(plistlib.dumps(privacy))
print(f'Generated Xcode project: {len(source_paths)} Swift files, {len(resources)} resources')
