require "bundler/gem_tasks"
require 'rake/extensiontask'
require 'rake/testtask'

task :default => [:compile, :test]

Rake::ExtensionTask.new('core') do |ext|
  ext.ext_dir = 'ext/epoll'
  ext.lib_dir = 'lib/epoll'
end
Rake::TestTask.new {|t| t.libs << 'test'}
