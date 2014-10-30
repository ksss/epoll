require "bundler/gem_tasks"
require 'rake/extensiontask'
require 'rake/testtask'

Rake::ExtensionTask.new('epoll') do |ext|
  ext.name = 'epoll'
  ext.ext_dir = 'ext/io/epoll'
  ext.lib_dir = 'lib/io/epoll'
end
Rake::TestTask.new {|t| t.libs << 'test'}

