# frozen_string_literal: true

require_relative "lib/clef/version"

Gem::Specification.new do |spec|
  spec.name = "clef"
  spec.version = Clef::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "Ruby toolkit for building small scores and exporting PDF, SVG, or MIDI."
  spec.description = "Clef provides a Ruby DSL, LilyPond-style note input, and a small LilyPond-style syntax parser for modeling simple scores and exporting them to PDF, SVG, or MIDI."
  spec.homepage = "https://github.com/ydah/clef"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore .rspec spec/ .github/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "nokogiri", "~> 1.16"
  spec.add_dependency "prawn", "~> 2.4"
  spec.add_dependency "midilib", "~> 4.0"
end
