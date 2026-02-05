# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new do |t|
  t.options = ["--autocorrect"]
end

require "rake/gem_maintenance/install_tasks"

task default: :verify

desc "Run all verification tasks"
task verify: %i[spec rubocop]
