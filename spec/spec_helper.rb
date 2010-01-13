require 'pathname'
require 'rubygems'

require 'addressable/uri'
require 'spec'

require 'ruby-debug'

require 'dm-core'

SPEC_ROOT = Pathname(__FILE__).dirname.expand_path
# $LOAD_PATH.unshift(SPEC_ROOT.parent + 'lib')

Pathname.glob((SPEC_ROOT + '{lib,*/shared}/**/*.rb').to_s).each { |file| require file }

# ENV['ADAPTERS'] ||= 'all'
# 
# ADAPTERS = []
# 
# PRIMARY = {
#   'persevere' => {:adapter => 'persevere', :host => 'localhost', :port => '8080'}
# }
# 
# adapters = ENV['ADAPTERS'].split(' ').map { |adapter_name| adapter_name.strip.downcase }.uniq
# adapters = PRIMARY.keys if adapters.include?('all')
# 
# PRIMARY.only(*adapters).each do |name, default|
#   connection_string = ENV["#{name.upcase}_SPEC_URI"] || default
#   begin
#     adapter = DataMapper.setup(name.to_sym, connection_string)
# 
#     # test the connection if possible
#     if adapter.respond_to?(:query)
#       name == 'oracle' ? adapter.select('SELECT 1 FROM dual') : adapter.select('SELECT 1')
#     end
# 
#     ADAPTERS << name
#     PRIMARY[name] = connection_string  # ensure *_SPEC_URI is saved
#    rescue Exception => exception
#      puts "Could not connect to the database using #{connection_string.inspect} because: #{exception.inspect}"
#   end
# end

logger = DataMapper::Logger.new(DataMapper.root / 'log' / 'dm.log', :debug)
logger.auto_flush = true

Spec::Runner.configure do |config|
  config.extend(DataMapper::Spec::AdapterHelpers)
  # config.include(DataMapper::Spec::PendingHelpers)
end