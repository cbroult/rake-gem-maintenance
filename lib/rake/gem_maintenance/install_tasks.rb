# frozen_string_literal: true

# TODO: Remove after releasing version that drops support for require "rake/gem_maintenance/install_tasks"
# This file exists for backward compatibility. Consumers should migrate to:
# require "rake/gem/maintenance/install_tasks"
warn 'DEPRECATED: require "rake/gem_maintenance/install_tasks" is deprecated. ' \
     'Use require "rake/gem/maintenance/install_tasks" instead.'
require "rake/gem/maintenance/install_tasks"
