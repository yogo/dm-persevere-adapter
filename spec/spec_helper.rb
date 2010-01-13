require 'pathname'
require 'rubygems'
require 'dm-core'
require 'extlib'

Spec::Runner.configure do |config|
  config.extend(DataMapper::Spec::AdapterHelpers)
  config.include(DataMapper::Spec::PendingHelpers)
end