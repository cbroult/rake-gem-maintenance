# frozen_string_literal: true

# TODO: After releasing version 1.0, remove this file and update consumers to:
# require "rake/gem/maintenance/version"
# require "rake/gem/maintenance/upgrade_task"
# require "rake/gem/maintenance/version_bump_task"
warn 'DEPRECATED: require "rake/gem_maintenance" is deprecated. Use require ' \
     '"rake/gem/maintenance/version", "rake/gem/maintenance/upgrade_task", and ' \
     '"rake/gem/maintenance/version_bump_task" instead.'
require_relative "gem/maintenance/version"
require_relative "gem/maintenance/upgrade_task"
require_relative "gem/maintenance/version_bump_task"
