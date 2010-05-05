require 'rubygems'
require 'rake'
require 'pathname'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = %q{dm-persevere-adapter}
    gemspec.summary = %q{A DataMapper Adapter for persevere}
    gemspec.description = %q{A DataMapper Adapter for persevere}
    gemspec.email = ["irjudson [a] gmail [d] com"]
    gemspec.homepage = %q{http://github.com/yogo/dm-persevere-adapter}
    gemspec.authors = ["Ivan R. Judson", "The Yogo Data Management Development Team" ]
    gemspec.rdoc_options = ["--main", "README.txt"]
    gemspec.add_dependency(%q<dm-core>, [">= 0.10.1"])
    gemspec.add_dependency(%q<extlib>)
  end

  Jeweler::GemcutterTasks.new
  FileList['tasks/**/*.rake'].each { |task| import task }
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

#task :spec => :check_dependencies
#task :default => :spec

ROOT    = Pathname(__FILE__).dirname.expand_path
JRUBY   = RUBY_PLATFORM =~ /java/
WINDOWS = Gem.win_platform?
SUDO    = (WINDOWS || JRUBY) ? '' : ('sudo' unless ENV['SUDOLESS'])