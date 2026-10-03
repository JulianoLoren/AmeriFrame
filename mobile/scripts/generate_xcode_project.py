#!/usr/bin/env python3
"""Dependency-free, deterministic Xcode project generator. Run after adding source files."""
from pathlib import Path
import hashlib
import json
root = Path(__file__).resolve().parents[1] / 'ios'
project = root / 'Mosaic.xcodeproj'
project.mkdir(exist_ok=True)
objects = {}
def uid(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def obj(key_name, isa, **values):
    key=uid(key_name); objects[key]={'isa':isa, **values}; return key
files=[]; sources=[]; resources=[]
for path in sorted((root/'Mosaic').iterdir()):
    if path.suffix not in ['.swift','.mm','.h','.plist','.xcassets','.xcprivacy']: continue
    kind={'.swift':'sourcecode.swift','.mm':'sourcecode.cpp.objcpp','.h':'sourcecode.c.h','.plist':'text.plist.xml','.xcassets':'folder.assetcatalog','.xcprivacy':'text.xml'}[path.suffix]
    ref=obj(str(path.name),'PBXFileReference',lastKnownFileType=kind,path='Mosaic/'+path.name,sourceTree='<group>'); files.append(ref)
    if path.suffix in ['.swift','.mm']: sources.append(obj('build'+path.name,'PBXBuildFile',fileRef=ref))
    if path.suffix in ['.xcassets','.xcprivacy']: resources.append(obj('build'+path.name,'PBXBuildFile',fileRef=ref))
ref=obj('Geometry.cpp','PBXFileReference',lastKnownFileType='sourcecode.cpp.cpp',path='../core/Geometry.cpp',sourceTree='<group>'); files.append(ref)
sources.append(obj('buildGeometry','PBXBuildFile',fileRef=ref))
product=obj('app','PBXFileReference',explicitFileType='wrapper.application',path='Mosaic.app',sourceTree='BUILT_PRODUCTS_DIR')
products=obj('products','PBXGroup',children=[product],name='Products',sourceTree='<group>')
group=obj('main','PBXGroup',children=files+[products],sourceTree='<group>')
sourcePhase=obj('sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=sources,runOnlyForDeploymentPostprocessing=0)
resourcePhase=obj('resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resources,runOnlyForDeploymentPostprocessing=0)
frameworkPhase=obj('frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
base={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'17.0','CLANG_CXX_LANGUAGE_STANDARD':'c++17','OTHER_CPLUSPLUSFLAGS':'-ffp-contract=off','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','SWIFT_VERSION':'5.0','SWIFT_OBJC_BRIDGING_HEADER':'Mosaic/GeometryBridge.h','PRODUCT_BUNDLE_IDENTIFIER':'com.ameriframe.mosaic','PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'Mosaic/Info.plist','TARGETED_DEVICE_FAMILY':'1,2','CODE_SIGN_STYLE':'Automatic','ENABLE_TESTABILITY':'YES','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','ENABLE_USER_SCRIPT_SANDBOXING':'YES'}
def configs(prefix, settings):
    refs=[]
    for name in ['Debug','Release']:
        cfg={**settings}
        if prefix=='target': cfg.update({'SWIFT_OPTIMIZATION_LEVEL':'-Onone' if name=='Debug' else '-O','GCC_OPTIMIZATION_LEVEL':'0' if name=='Debug' else 's','DEBUG_INFORMATION_FORMAT':'dwarf' if name=='Debug' else 'dwarf-with-dsym'})
        refs.append(obj(prefix+name,'XCBuildConfiguration',buildSettings=cfg,name=name))
    return obj(prefix+'config','XCConfigurationList',buildConfigurations=refs,defaultConfigurationIsVisible=0,defaultConfigurationName='Release')
target=obj('target','PBXNativeTarget',buildConfigurationList=configs('target',base),buildPhases=[sourcePhase,frameworkPhase,resourcePhase],buildRules=[],dependencies=[],name='Mosaic',productName='Mosaic',productReference=product,productType='com.apple.product-type.application')
testRef=obj('CollageTests.swift','PBXFileReference',lastKnownFileType='sourcecode.swift',path='MosaicTests/CollageTests.swift',sourceTree='<group>')
objects[group]['children'].append(testRef)
testProduct=obj('testProduct','PBXFileReference',explicitFileType='wrapper.cfbundle',path='MosaicTests.xctest',sourceTree='BUILT_PRODUCTS_DIR')
objects[products]['children'].append(testProduct)
testSources=obj('testSources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[obj('buildTests','PBXBuildFile',fileRef=testRef)],runOnlyForDeploymentPostprocessing=0)
proxy=obj('testProxy','PBXContainerItemProxy',containerPortal=uid('project'),proxyType=1,remoteGlobalIDString=target,remoteInfo='Mosaic')
dependency=obj('testDependency','PBXTargetDependency',target=target,targetProxy=proxy)
testSettings={k:v for k,v in base.items() if k not in ['SWIFT_OBJC_BRIDGING_HEADER','INFOPLIST_FILE','ASSETCATALOG_COMPILER_APPICON_NAME']}
testSettings.update({'PRODUCT_BUNDLE_IDENTIFIER':'com.ameriframe.mosaic.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Mosaic.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/Mosaic','BUNDLE_LOADER':'$(TEST_HOST)'})
testTarget=obj('testTarget','PBXNativeTarget',buildConfigurationList=configs('tests',testSettings),buildPhases=[testSources],buildRules=[],dependencies=[dependency],name='MosaicTests',productName='MosaicTests',productReference=testProduct,productType='com.apple.product-type.bundle.unit-test')
proj=obj('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600'},buildConfigurationList=configs('project',{}),compatibilityVersion='Xcode 14.0',developmentRegion='en',knownRegions=['en','vi','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=[target,testTarget])
def encode(value, depth=0):
    if isinstance(value,dict): return '{\n'+''.join('\t'*(depth+1)+json.dumps(k)+' = '+encode(v,depth+1)+';\n' for k,v in value.items())+'\t'*depth+'}'
    if isinstance(value,list): return '('+', '.join(encode(v,depth) for v in value)+')'
    return str(value) if isinstance(value,int) else json.dumps(value)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':proj})+'\n')
schemes=project/'xcshareddata/xcschemes'; schemes.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Mosaic.app" BlueprintName="Mosaic" ReferencedContainer="container:Mosaic.xcodeproj"/>'
(schemes/'Mosaic.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{testTarget}" BuildableName="MosaicTests.xctest" BlueprintName="MosaicTests" ReferencedContainer="container:Mosaic.xcodeproj"/></TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(project)
