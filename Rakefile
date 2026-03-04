# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yard)
rescue LoadError
  task :yard do
    warn("YARD is not installed. Run: bundle add yard --group development")
  end
end

task default: :spec
