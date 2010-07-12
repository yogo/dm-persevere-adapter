require 'rubygems'
require 'rake'
require 'pathname'

begin
  require 'bundler'
rescue LoadError
  puts "Bundler is not intalled. Install with: gem install bundler"
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gemspec|
    gemspec.name = %q{dm-persevere-adapter}
    gemspec.summary = %q{A DataMapper Adapter for persevere}
    gemspec.description = %q{A DataMapper Adapter for persevere}
    gemspec.email = ["irjudson [a] gmail [d] com"]
    gemspec.homepage = %q{http://github.com/yogo/dm-persevere-adapter}
    gemspec.authors = ["Ivan R. Judson", "Ryan Heimbuch", "The Yogo Data Management Development Team" ]
    gemspec.rdoc_options = ["--main", "README.txt"]
    gemspec.add_bundler_dependencies
  end

  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

begin
  require 'yard'
  YARD::Rake::YardocTask.new
rescue LoadError
  task :yardoc do
    abort "YARD is not available. In order to run yardoc, you must: sudo gem install yard"
  end
end

FileList['tasks/**/*.rake'].each { |task| import task }

ROOT    = Pathname(__FILE__).dirname.expand_path
JRUBY   = RUBY_PLATFORM =~ /java/
WINDOWS = Gem.win_platform?
SUDO    = (WINDOWS || JRUBY) ? '' : ('sudo' unless ENV['SUDOLESS'])