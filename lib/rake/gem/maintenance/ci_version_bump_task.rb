# frozen_string_literal: true

require "rake"
require "rake/tasklib"
require "net/http"
require "openssl"
require "base64"
require "open3"

module Rake
  module Gem
    module Maintenance
      # Defines `version:ci_bump` — auto-bump for CI push pipelines.
      #
      # Checks whether the current version is already published at the configured
      # registry. If yes: patch-bumps, commits with [skip ci], tags, and pushes.
      # If no: assumes the developer already bumped and does nothing.
      # Either way skips if the HEAD commit message contains any skip_pattern.
      #
      # Usage in Rakefile:
      #   Rake::Gem::Maintenance::CiVersionBumpTask.new do |t|
      #     t.registry_url   = 'https://gems.cbp-org.internal'
      #     t.ca_cert_env    = 'CBP_ORG_CA_CERT'      # base64-encoded PEM, optional
      #     t.push_token_env = 'FORGEJO_PUSH_TOKEN'    # token for git push auth, optional
      #   end
      class CiVersionBumpTask < ::Rake::TaskLib
        attr_accessor :registry_url, :ca_cert_env, :push_token_env,
                      :skip_patterns, :push_branch, :git_author_email, :git_author_name

        def initialize
          super
          @registry_url     = "https://rubygems.org"
          @ca_cert_env      = nil
          @push_token_env   = nil
          @skip_patterns    = ["[skip bump]", "[skip ci]"]
          @push_branch      = "main"
          @git_author_email = "ci@cbp-org.internal"
          @git_author_name  = "CBP-Org-CI"
          yield self if block_given?
          define_tasks
        end

        private

        def define_tasks
          desc "CI auto-bump: patch-bump if already published; skip if developer already bumped"
          task "version:ci_bump" do
            run_ci_bump
          end
        end

        def run_ci_bump
          return if head_opts_out?

          current = current_version
          if already_published?(current)
            puts "auto-bump: #{current} is already published — bumping patch"
            perform_bump(current)
          else
            puts "auto-bump: #{current} not yet published — no action needed"
          end
        end

        def head_opts_out?
          msg = head_commit_message
          return false unless skip?(msg)

          puts "auto-bump: HEAD opts out — leaving version alone"
          true
        end

        def perform_bump(current)
          system("git checkout -- .") or abort("auto-bump: git checkout failed")
          system("bundle exec gem bump --version patch --file #{version_file} --no-commit") or
            abort("auto-bump: gem bump failed")
          new_version = current_version
          abort("auto-bump: gem bump did not change version") if new_version == current
          puts "auto-bump: bumped to #{new_version}"
          commit_and_push(new_version)
        end

        def commit_and_push(new_version)
          git_cfg = ["-c", "user.email=#{git_author_email}", "-c", "user.name=#{git_author_name}"]
          system("git", *git_cfg, "add", version_file) or abort("auto-bump: git add failed")
          system("git", *git_cfg, "commit", "-m",
                 "chore: auto-bump version to #{new_version} [skip ci]") or
            abort("auto-bump: git commit failed")
          system("git", "tag", "v#{new_version}") or abort("auto-bump: git tag failed")
          system("git", "push", authenticated_url(origin_url), "HEAD:#{push_branch}",
                 "--tags") or abort("auto-bump: git push failed")
          puts "auto-bump: pushed v#{new_version}"
        end

        def skip?(message)
          skip_patterns.any? { |pattern| message.include?(pattern) }
        end

        def head_commit_message
          stdout, status = Open3.capture2("git log -1 --pretty=%B")
          status.success? ? stdout.strip : abort("auto-bump: git log failed")
        end

        def origin_url
          url, status = Open3.capture2("git remote get-url origin")
          status.success? ? url.strip : abort("auto-bump: could not determine origin URL")
        end

        def current_version
          content = File.read(version_file)
          content[/VERSION\s*=\s*['"]([^'"]+)['"]/, 1] ||
            abort("auto-bump: could not parse VERSION from #{version_file}")
        end

        def already_published?(version)
          uri = URI("#{registry_url}/gems/#{gem_name}-#{version}.gem")
          res = Net::HTTP.start(uri.host, uri.port,
                                use_ssl: true, cert_store: build_cert_store,
                                verify_mode: OpenSSL::SSL::VERIFY_PEER) { |h| h.head(uri.path) }
          res.is_a?(Net::HTTPSuccess)
        rescue StandardError
          false
        end

        def build_cert_store
          store = OpenSSL::X509::Store.new
          store.set_default_paths
          if ca_cert_env && (b64 = ENV.fetch(ca_cert_env, nil))
            store.add_cert(OpenSSL::X509::Certificate.new(Base64.decode64(b64)))
          end
          store
        end

        def authenticated_url(url)
          return url unless push_token_env && (token = ENV.fetch(push_token_env, nil))

          url.sub("https://", "https://x-access-token:#{token}@")
        end

        def version_file
          @version_file ||= Dir.glob("lib/**/version.rb").first
        end

        def gem_name
          @gem_name ||= ::Gem::Specification.load(Dir.glob("*.gemspec").first).name
        end
      end
    end
  end
end
