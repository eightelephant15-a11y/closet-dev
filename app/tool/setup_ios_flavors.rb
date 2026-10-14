# Idempotent: adds dev/staging/prod build configurations, xcconfig wiring, localisation, the
# Firebase-plist copy phase and shared schemes to ios/Runner.xcodeproj.
#   cd app/ios && ruby ../tool/setup_ios_flavors.rb
require 'xcodeproj'
require 'fileutils'

FLAVORS = %w[dev staging prod].freeze
MODES = %w[Debug Release Profile].freeze

project = Xcodeproj::Project.open('Runner.xcodeproj')
runner = project.targets.find { |t| t.name == 'Runner' }
tests = project.targets.find { |t| t.name == 'RunnerTests' }
flutter_group = project.main_group['Flutter']
runner_group = project.main_group['Runner']

def file_ref(group, path)
  group.files.find { |f| f.path == path } || group.new_file(path)
end

def clone_config(project, list, base_name, new_name)
  return list.build_configurations.find { |c| c.name == new_name } if list.build_configurations.any? { |c| c.name == new_name }

  base = list.build_configurations.find { |c| c.name == base_name }
  cfg = project.new(Xcodeproj::Project::Object::XCBuildConfiguration)
  cfg.name = new_name
  cfg.build_settings = Marshal.load(Marshal.dump(base.build_settings))
  cfg.base_configuration_reference = base.base_configuration_reference
  list.build_configurations << cfg
  cfg
end

flavor_refs = FLAVORS.to_h { |f| [f, file_ref(flutter_group, "Flutter/flavors/#{f}.xcconfig")] }

[project, runner, tests].each do |owner|
  list = owner.build_configuration_list
  FLAVORS.each do |flavor|
    MODES.each do |mode|
      cfg = clone_config(project, list, mode, "#{mode}-#{flavor}")
      if owner.equal?(runner)
        cfg.base_configuration_reference = file_ref(flutter_group, "Flutter/#{mode}-#{flavor}.xcconfig")
      elsif owner.equal?(tests)
        cfg.base_configuration_reference = flavor_refs[flavor]
      end
    end
  end
end

# Runner: identity comes from the flavor xcconfig, not from build settings.
runner.build_configuration_list.build_configurations.each do |cfg|
  %w[PRODUCT_BUNDLE_IDENTIFIER ASSETCATALOG_COMPILER_APPICON_NAME].each { |k| cfg.build_settings.delete(k) }
end
# Base (un-flavoured) configs follow prod via Debug.xcconfig / Release.xcconfig; Profile uses Release.xcconfig.
tests.build_configuration_list.build_configurations.each do |cfg|
  cfg.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = '$(APP_BUNDLE_ID).RunnerTests'
  cfg.base_configuration_reference ||= flavor_refs['prod']
end

# Localised permission strings (generated from the ARB by tool/gen_ios_strings.py).
unless runner_group.children.any? { |c| c.display_name == 'InfoPlist.strings' }
  variant = project.new(Xcodeproj::Project::Object::PBXVariantGroup)
  variant.name = 'InfoPlist.strings'
  variant.source_tree = '<group>'
  runner_group << variant
  en = variant.new_reference('en.lproj/InfoPlist.strings')
  en.name = 'en'
  runner.resources_build_phase.add_file_reference(variant)
end
project.root_object.known_regions = (project.root_object.known_regions + ['en']).uniq

file_ref(runner_group, 'Runner.entitlements')

# Firebase plist slot: copies ios/config/<flavor>/GoogleService-Info.plist when it exists.
unless runner.shell_script_build_phases.any? { |p| p.name == 'Copy GoogleService-Info.plist' }
  phase = runner.new_shell_script_build_phase('Copy GoogleService-Info.plist')
  phase.shell_script = <<~SH
    SRC="${SRCROOT}/config/${FLAVOR_NAME}/GoogleService-Info.plist"
    DST="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/GoogleService-Info.plist"
    if [ -f "$SRC" ]; then
      cp "$SRC" "$DST"
    else
      echo "warning: ${SRC} not found: Firebase is disabled in this build (fine for mock mode). See docs/rename-app.md."
    fi
  SH
  phase.always_out_of_date = '1'
  # run after resources are copied
  runner.build_phases.move(phase, runner.build_phases.index(runner.resources_build_phase) + 1)
end

# Minimum iOS: firebase_auth requires 15.0 (iPhone 12 and newer all run iOS 15+).
MIN_IOS = '15.0'.freeze
[project, runner, tests].each do |owner|
  owner.build_configuration_list.build_configurations.each do |cfg|
    cfg.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = MIN_IOS if cfg.build_settings.key?('IPHONEOS_DEPLOYMENT_TARGET')
  end
end
project.save

# Shared schemes: one per flavor, mapped to <Mode>-<flavor> configurations.
base_scheme = File.read('Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme')
FLAVORS.each do |flavor|
  xml = base_scheme.gsub(/buildConfiguration = "(Debug|Release|Profile)"/) { "buildConfiguration = \"#{$1}-#{flavor}\"" }
  File.write("Runner.xcodeproj/xcshareddata/xcschemes/#{flavor}.xcscheme", xml)
end

# Podfile: tell CocoaPods which flavored configurations are debug/release.
podfile = File.read('Podfile')
mapping = FLAVORS.flat_map do |f|
  [%("Debug-#{f}" => :debug), %("Profile-#{f}" => :release), %("Release-#{f}" => :release)]
end
block = "project 'Runner', {\n  'Debug' => :debug,\n  'Profile' => :release,\n  'Release' => :release,\n" +
        mapping.map { |m| "  #{m},\n" }.join + "}\n"
podfile.sub!(/^#? ?platform :ios, '[0-9.]+'/, "platform :ios, '15.0'")
podfile.sub!(/project 'Runner', \{.*?\n\}\n/m, block)
File.write('Podfile', podfile)
puts 'iOS flavors configured'
