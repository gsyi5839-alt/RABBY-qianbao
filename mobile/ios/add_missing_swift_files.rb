#!/usr/bin/env ruby
# Script to add all missing .swift files under RabbyMobile/ to the Xcode project.

require 'xcodeproj'
require 'pathname'

PROJECT_PATH = '/Users/macbook/Downloads/Rabby-0.93.77/mobile/ios/RabbyMobile.xcodeproj'
SOURCE_DIR   = '/Users/macbook/Downloads/Rabby-0.93.77/mobile/ios/RabbyMobile'

# Open the project
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the RabbyMobile target
target = project.targets.find { |t| t.name == 'RabbyMobile' }
unless target
  puts "ERROR: Could not find target 'RabbyMobile'. Available targets:"
  project.targets.each { |t| puts "  - #{t.name}" }
  exit 1
end
puts "Found target: #{target.name}"

# Get the compile sources build phase
sources_phase = target.source_build_phase
puts "Current compile sources count: #{sources_phase.files.count}"

# Collect all file paths currently in compile sources (resolve to absolute paths)
existing_paths = Set.new
sources_phase.files.each do |build_file|
  ref = build_file.file_ref
  next unless ref
  begin
    abs = ref.real_path.to_s
    existing_paths.add(abs)
  rescue => e
    # Some references might not resolve; skip them
  end
end
puts "Existing source file paths resolved: #{existing_paths.count}"

# Discover all .swift files on disk
swift_files = Dir.glob(File.join(SOURCE_DIR, '**', '*.swift')).sort
puts "\nSwift files on disk: #{swift_files.count}"

# Find the main RabbyMobile group in the project
main_group = project.main_group.children.find { |g| g.respond_to?(:name) && g.name == 'RabbyMobile' } ||
             project.main_group.children.find { |g| g.respond_to?(:path) && g.path == 'RabbyMobile' }

unless main_group
  puts "ERROR: Could not find the 'RabbyMobile' group in the project. Top-level groups:"
  project.main_group.children.each do |child|
    puts "  - name=#{child.respond_to?(:name) ? child.name : 'nil'} path=#{child.respond_to?(:path) ? child.path : 'nil'} class=#{child.class}"
  end
  exit 1
end
puts "Found main group: #{main_group.display_name} (path: #{main_group.path})"

# Helper: find or create a nested group matching the directory structure.
def find_or_create_group(parent_group, group_components)
  current = parent_group
  group_components.each do |component|
    child = current.children.find { |c|
      c.is_a?(Xcodeproj::Project::Object::PBXGroup) &&
        (c.name == component || c.path == component)
    }
    unless child
      child = current.new_group(component, component)
      puts "  Created group: #{component} under #{current.display_name}"
    end
    current = child
  end
  current
end

added_count = 0
already_in_build_phase = 0

swift_files.each do |swift_path|
  # Compute relative path from SOURCE_DIR
  relative = Pathname.new(swift_path).relative_path_from(Pathname.new(SOURCE_DIR)).to_s
  dir_components = File.dirname(relative).split('/')
  dir_components = [] if dir_components == ['.']
  filename = File.basename(relative)

  # Check if already in compile sources
  if existing_paths.include?(swift_path)
    already_in_build_phase += 1
    next
  end

  # Find or create the appropriate group
  group = find_or_create_group(main_group, dir_components)

  # Check if a file reference already exists in this group for this file
  existing_ref = group.children.find { |c|
    c.is_a?(Xcodeproj::Project::Object::PBXFileReference) &&
      c.path == filename
  }

  if existing_ref
    # File reference exists but was not in compile sources -- add it
    puts "  Adding existing ref to compile sources: #{relative}"
    target.source_build_phase.add_file_reference(existing_ref)
    added_count += 1
  else
    # Create a new file reference and add to compile sources
    file_ref = group.new_file(filename)
    file_ref.source_tree = '<group>'
    file_ref.path = filename
    target.source_build_phase.add_file_reference(file_ref)
    puts "  Added new file: #{relative}"
    added_count += 1
  end
end

puts "\n=== Summary ==="
puts "Swift files on disk:          #{swift_files.count}"
puts "Already in compile sources:   #{already_in_build_phase}"
puts "Newly added to build phase:   #{added_count}"
puts "Total compile sources now:    #{target.source_build_phase.files.count}"

# Save the project
project.save
puts "\nProject saved successfully!"
