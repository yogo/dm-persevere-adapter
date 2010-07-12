require 'rubygems'
require 'bundler'
Bundler.setup

require 'pathname'
require 'addressable/uri'

require 'ruby-debug'
Debugger.start

require 'dm-core'
require 'extlib'

def path_to(gem_name, version=nil)
  version = version ? Gem::Requirement.create(version) : Gem::Requirement.default
  specs = Gem.source_index.find_name(gem_name, version)
  paths = specs.map do |spec|
    spec_path = spec.loaded_from
    expanded_path = File.join(File.dirname(spec_path), '..', 'gems', "#{spec.name}-#{spec.version}")
  end
end

def path_in_gem(name, *paths)
  loaded_gem = Gem.loaded_specs[name]
  return null unless loaded_gem
  
  File.join(loaded_gem.full_gem_path, *paths)
end
