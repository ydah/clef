# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rbconfig"
require "tmpdir"

RSpec::Core::RakeTask.new(:spec)

desc "Run Standard Ruby lint"
task :lint do
  sh({"RUBOCOP_CACHE_ROOT" => "tmp/rubocop_cache"}, "bundle", "exec", "standardrb")
end

desc "Run Ruby syntax checks"
task :syntax do
  files = FileList["lib/**/*.rb", "spec/**/*.rb", "exe/*", "*.gemspec", "Rakefile"]
  files.each { |file| sh RbConfig.ruby, "-c", file }
end

desc "Build the gem into a temporary directory"
task :build_smoke do
  Dir.mktmpdir do |dir|
    sh "gem", "build", "clef.gemspec", "--output", File.join(dir, "clef.gem")
  end
end

begin
  require "yard"
  YARD::Rake::YardocTask.new(:yard)
rescue LoadError
  task :yard do
    warn("YARD is not installed. Run: bundle add yard --group development")
  end
end

task default: %i[spec lint syntax build_smoke]
