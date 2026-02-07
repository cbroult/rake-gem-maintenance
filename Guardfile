# frozen_string_literal: true

guard "bundler" do
  require "guard/bundler"
  require "guard/bundler/verify"
  helper = Guard::Bundler::Verify.new

  files = ["Gemfile"]
  files += Dir["*.gemspec"] if files.any? { |f| helper.uses_gemspec?(f) }

  files.each { |file| watch(helper.real_path(file)) }
end

group :red_green_refactor, halt_on_fail: true do
  guard "rspec", cmd: "bundle exec rspec" do
    require "guard/rspec/dsl"
    dsl = Guard::RSpec::Dsl.new(self)

    rspec = dsl.rspec
    watch(rspec.spec_helper) { rspec.spec_dir }
    watch(rspec.spec_support) { rspec.spec_dir }
    watch(rspec.spec_files)

    ruby = dsl.ruby
    dsl.watch_spec_files_for(ruby.lib_files)
  end

  guard "cucumber", notification: false do
    watch(%r{^features/.+\.feature$})
    watch(%r{^features/support/.+$}) { "features" }
    watch(%r{^features/step_definitions/.+$}) { "features" }
    watch(%r{^lib/.+\.rb$}) { "features" }
  end

  guard "rubocop", cli: ["--format", "clang", "--autocorrect"] do
    watch(/.+\.rb$/)
    watch(%r{(?:.+/)?\.rubocop(?:_todo)?\.yml$}) { |m| m[0] ? File.dirname(m[0]) : "." }
  end
end
