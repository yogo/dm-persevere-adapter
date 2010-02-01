require 'rubygems'
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
  # Jeweler::Tasks.new do |gemspec|
  #    gemspec.name = %q{persevere}
  #    gemspec.summary = %q{A ruby wrapper for persevere}
  #    gemspec.description = %q{A ruby wrapper for persevere}
  #    gemspec.email = ["irjudson [a] gmail [d] com"]
  #    gemspec.homepage = %q{http://github.com/yogo/persevere}
  #    gemspec.authors = ["Ivan R. Judson", "The Yogo Data Management Development Team" ]
  #    gemspec.rdoc_options = ["--main", "persevere/README.txt"]
  #    gemspec.files = ["LICENSE.txt", "persevere/History.txt", "persevere/README.txt", "Rakefile", "lib/persevere.rb"]
  #    gemspec.test_files = ["spec/persevere_spec.rb", "spec/spec.opts", "spec/spec_helper.rb"]
  #  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler not available. Install it with: gem install jeweler"
end

ROOT    = Pathname(__FILE__).dirname.expand_path
JRUBY   = RUBY_PLATFORM =~ /java/
WINDOWS = Gem.win_platform?
SUDO    = (WINDOWS || JRUBY) ? '' : ('sudo' unless ENV['SUDOLESS'])

Pathname.glob(ROOT.join('tasks/**/*.rb').to_s).each { |f| require f }