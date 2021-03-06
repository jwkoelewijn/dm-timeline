require 'rubygems'

gem 'dm-core', '>=1.2.0'
gem 'gettext'
require 'dm-core'
require 'gettext'

spec_dir_path = File.dirname(__FILE__)

def load_driver(name, default_uri)
  return false if ENV['ADAPTER'] != name.to_s
 
  lib = "do_#{name}"
 
  begin
    gem lib, '>=0.9.2'
    require lib
    DataMapper.setup(name, ENV["#{name.to_s.upcase}_SPEC_URI"] || default_uri)
    DataMapper::Repository.adapters[:default] =  DataMapper::Repository.adapters[name]
 
    FileUtils.touch LOG_PATH
    DataMapper::Logger.new(LOG_PATH, 0)
    at_exit { DataMapper.logger.close }
    true
  rescue Gem::LoadError => e
    warn "Could not load #{lib}: #{e}"
    false
  end
end
 
ENV['ADAPTER'] ||= 'sqlite3'

LOG_PATH     = File.join(File.dirname(__FILE__), '/sql.log')
HAS_SQLITE3  = load_driver(:sqlite3,  'sqlite3::memory:')
HAS_MYSQL    = load_driver(:mysql,    'mysql://localhost/dm_core_test')
HAS_POSTGRES = load_driver(:postgres, 'postgres://postgres@localhost/dm_core_test')

require File.join(spec_dir_path, '..', 'lib/dm-timeline')

Dir[spec_dir_path + "fixtures/*.rb"].each do |fixture_file|
  require fixture_file
end
