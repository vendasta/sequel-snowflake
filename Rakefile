#!/usr/bin/env rake
require 'bundler/gem_tasks'

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new

desc 'Run specs'
task :test    => :spec
task :default => :spec

desc 'All-in-one target for CI servers to run.'
task :ci => ['spec']
