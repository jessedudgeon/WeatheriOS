"""Idempotently register shared Swift files and both automated-test schemes."""
from pathlib import Path
import hashlib
import plistlib

root = Path(__file__).resolve().parents[1]
project = root / 'Weather.xcodeproj/project.pbxproj'
s = project.read_text()

def ident(text):
    return hashlib.sha1(text.encode()).hexdigest()[:24].upper()

for path in ['Core/WeatherModels.swift', 'WeatherProvider.swift', 'LocationManager.swift', 'WeatherViewModel.swift', 'PreviewWeather.swift', 'Core/OpenMeteoResponse.swift', 'Core/FishingOutlook.swift', 'OpenMeteoProvider.swift', 'FishingView.swift', 'WeatherMapView.swift', 'Core/WeatherModule.swift', 'ModuleStore.swift', 'ModuleViews.swift']:
    ref = ident(path)
    if ref in s:
        continue
    filename = Path(path).name
    s = s.replace('/* End PBXFileReference section */', f'\t\t{ref} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{path}"; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
    group = 'CE421B37288B655700A2BD53 /* Shared */ = {'
    start = s.index(group)
    pos = s.index('children = (', start) + len('children = (')
    s = s[:pos] + f'\n\t\t\t\t{ref} /* {filename} */,' + s[pos:]
    for target, phase in [('ios','CE421B3B288B655800A2BD53'),('mac','CE421B41288B655800A2BD53')]:
        build = ident(path + target)
        s = s.replace('/* End PBXBuildFile section */', f'\t\t{build} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {ref}; }};\n/* End PBXBuildFile section */')
        start = s.index(phase + ' /* Sources */ = {')
        pos = s.index('files = (', start) + len('files = (')
        s = s[:pos] + f'\n\t\t\t\t{build} /* {filename} in Sources */,' + s[pos:]
# The privacy manifest must be bundled in both apps, not just present in the repo.
resource = 'PrivacyInfo.xcprivacy'
ref = ident(resource)
if ref not in s:
    s = s.replace('/* End PBXFileReference section */', f'\t\t{ref} /* {resource} */ = {{isa = PBXFileReference; lastKnownFileType = text.xml; path = "{resource}"; sourceTree = "<group>"; }};\n/* End PBXFileReference section */')
    pos = s.index('children = (', s.index('CE421B37288B655700A2BD53 /* Shared */ = {')) + len('children = (')
    s = s[:pos] + f'\n\t\t\t\t{ref} /* {resource} */,' + s[pos:]
    for target, phase in [('ios', 'CE421B3D288B655800A2BD53'), ('mac', 'CE421B43288B655800A2BD53')]:
        build = ident(resource + target)
        s = s.replace('/* End PBXBuildFile section */', f'\t\t{build} /* {resource} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref}; }};\n/* End PBXBuildFile section */')
        pos = s.index('files = (', s.index(phase + ' /* Resources */ = {')) + len('files = (')
        s = s[:pos] + f'\n\t\t\t\t{build} /* {resource} in Resources */,' + s[pos:]
# Bundle local StoreKit data only with UI tests; production products come from Apple.
resource = 'WeatherModules.storekit'
ref = ident(resource)
if ref not in s:
    s = s.replace('/* End PBXFileReference section */', f'\t\t{ref} /* {resource} */ = {{isa = PBXFileReference; lastKnownFileType = text; path = "{resource}"; sourceTree = SOURCE_ROOT; }};\n/* End PBXFileReference section */')
    pos = s.index('children = (', s.index('CE421B4F288B655800A2BD53 /* Tests iOS */ = {')) + len('children = (')
    s = s[:pos] + f'\n\t\t\t\t{ref} /* {resource} */,' + s[pos:]
    build = ident(resource + 'iosTests')
    s = s.replace('/* End PBXBuildFile section */', f'\t\t{build} /* {resource} in Resources */ = {{isa = PBXBuildFile; fileRef = {ref}; }};\n/* End PBXBuildFile section */')
    pos = s.index('files = (', s.index('CE421B4A288B655800A2BD53 /* Resources */ = {')) + len('files = (')
    s = s[:pos] + f'\n\t\t\t\t{build} /* {resource} in Resources */,' + s[pos:]
s = s.replace('IPHONEOS_DEPLOYMENT_TARGET = 15.5;', 'IPHONEOS_DEPLOYMENT_TARGET = 16.0;')
s = s.replace('MACOSX_DEPLOYMENT_TARGET = 12.3;', 'MACOSX_DEPLOYMENT_TARGET = 13.0;')
s = s.replace('MARKETING_VERSION = 1.0;', 'MARKETING_VERSION = 1.1;')
s = s.replace('CURRENT_PROJECT_VERSION = 1;', 'CURRENT_PROJECT_VERSION = 2;')
for config in ['CE421B69288B655800A2BD53','CE421B6A288B655800A2BD53','CE421B6C288B655800A2BD53','CE421B6D288B655800A2BD53']:
    start = s.index(config + ' /*')
    # These IDs first appear in the configuration definition, before their lists.
    pos = s.index('buildSettings = {', start) + len('buildSettings = {')
    end = s.index('\n\t\t\t};', pos)
    if 'NSLocationWhenInUseUsageDescription' not in s[pos:end]:
        extra = '\n\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Weather uses your location only when requested to show your local forecast. You can search for a city instead.";'
        extra += '\n\t\t\t\tINFOPLIST_KEY_NSLocationUsageDescription = "Weather uses your location to show your local forecast when you request it.";'
        if config in ['CE421B69288B655800A2BD53','CE421B6A288B655800A2BD53']:
            extra += '\n\t\t\t\tCODE_SIGN_ENTITLEMENTS = Shared/Weather.entitlements;'
        s = s[:pos] + extra + s[pos:]
project.write_text(s)
for path, values in [('Shared/Weather.entitlements', {}), ('macOS/macOS.entitlements', {'com.apple.security.app-sandbox': True, 'com.apple.security.network.client': True, 'com.apple.security.personal-information.location': True})]:
    (root/path).write_bytes(plistlib.dumps(values))
for platform, app, test in [('iOS','CE421B3E288B655800A2BD53','CE421B4B288B655800A2BD53'),('macOS','CE421B44288B655800A2BD53','CE421B57288B655800A2BD53')]:
    def reference(id, name, product):
        return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{id}" BuildableName="{product}" BlueprintName="{name}" ReferencedContainer="container:Weather.xcodeproj"/>'
    appref = reference(app, f'Weather ({platform})', 'Weather.app')
    testref = reference(test, f'Tests {platform}', f'Tests {platform}.xctest')
    xml = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{appref}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{testref}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{appref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/>
<ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (root/f'Weather.xcodeproj/xcshareddata/xcschemes/Weather-{platform}.xcscheme').write_text(xml)
