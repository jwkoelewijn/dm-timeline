require 'rubygems'
require 'rspec/core'
require 'rspec/core/rake_task'
require 'rake/clean'
require 'rubygems/package_task'
require 'rake/tasklib'
require 'pathname'
 
CLEAN.include '{log,pkg}/'
 
spec = Gem::Specification.new do |s|
  s.name             = 'dm-timeline'
  s.version          = '0.0.2'
  s.platform         = Gem::Platform::RUBY
  s.has_rdoc         = true
  s.extra_rdoc_files = %w[ README LICENSE ]
  s.summary          = 'DataMapper plugin providing temporal object behavior'
  s.description      = s.summary
  s.authors          = ['Dirkjan Bussink', 'J.W. Koelewijn']
  s.email            = ['d.bussink@gmail.com', 'janwillem.koelewijn@nedap.com']
  s.homepage         = 'http://github.com/dbussink/dm-timeline'
  s.require_path     = 'lib'
  s.files            = FileList[ '{lib,spec}/**/*.rb', 'spec/spec.opts', 'Rakefile', *s.extra_rdoc_files ]
  s.add_dependency('dm-core', ">=1.2.0")
end
 
task :default => [ :spec ]
 
WIN32 = (RUBY_PLATFORM =~ /win32|mingw|cygwin/) rescue nil
SUDO  = WIN32 ? '' : ('sudo' unless ENV['SUDOLESS'])
 
Gem::PackageTask.new(spec) do |pkg|
  pkg.gem_spec = spec
end
 
desc "Install #{spec.name} #{spec.version}"
task :install => [ :package ] do
  sh "#{SUDO} gem install pkg/#{spec.name}-#{spec.version} --no-update-sources", :verbose => false
end
 
desc 'Run specifications'
RSpec::Core::RakeTask.new(:rspec) do |t|
  t.rspec_opts = 'spec/spec.opts' if File.exists?('spec/spec.opts')
  t.pattern = 'spec/**/*_spec.rb'
end
