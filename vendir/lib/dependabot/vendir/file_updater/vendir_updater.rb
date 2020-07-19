# frozen_string_literal: true

require "dependabot/shared_helpers"
require "dependabot/errors"
require "dependabot/vendir/file_updater"
require "pp"

module Dependabot
  module Vendir
    class FileUpdater
      class VendirUpdater
        def initialize(dependencies:, vendir_yml:, vendir_lock_yml:, credentials:)
            @dependencies = dependencies
            @vendir_yml = vendir_yml
            @vendir_lock_yml = vendir_lock_yml
            @credentials = credentials
        end

        def updated_vendir_yml_content
            updated_files[:vendir_yml]
        end

        def updated_vendir_lock_yml_content
            updated_files[:vendir_lock_yml]
        end

        private

        attr_reader :dependencies, :vendir_yml, :vendir_lock_yml, :credentials

        def updated_files
            @updated_files ||= update_files
        end
  
        # rubocop:disable Metrics/AbcSize
        def update_files
            SharedHelpers.in_a_temporary_directory do |path|
              SharedHelpers.with_git_configured(credentials: credentials) do
                File.write(vendir_yml.name, vendir_yml.content)
                File.write(vendir_lock_yml.name, vendir_lock_yml.content)

                dependencies.each do |dep|
                  dep_path = dep.requirements.first[:source][:path]
                  FileUtils.mkdir_p dep_path.join("/")
                end

                command = "vendir sync"
  
                _, stderr, status = Open3.capture3(command)
                handle_vendir_sync_error(path, stderr) unless status.success?

                updated_vendir_yml = File.read(vendir_yml.name)
                updated_vendir_lock_yml = File.read(vendir_lock_yml.name)
                { vendir_yml: updated_vendir_yml, vendir_lock_yml: updated_vendir_lock_yml }
              rescue Dependabot::DependencyFileNotResolvable
                # We sometimes see this error if a host times out.
                # In such cases, retrying (a maximum of 3 times) may fix it.
                retry_count ||= 0
                raise if retry_count >= 3
  
                retry_count += 1
                retry
              end
            end
        end

        GIT_ERROR_REGEX = /Error: .*: exit status 1/m.freeze
        VENDIR_MANUAL_SYNC_ERROR_REGEX = /Error: .*Moving directory.*to staging dir.*/m.freeze
        def handle_vendir_sync_error(path, stderr)
          case stderr
          when GIT_ERROR_REGEX
            lines = stderr.lines.drop_while { |l| GIT_ERROR_REGEX !~ l }
            raise Dependabot::DependencyFileNotResolvable.new, lines.join
          when VENDIR_MANUAL_SYNC_ERROR_REGEX
            return
          else
            msg = stderr.gsub(path.to_s, "").strip
            raise Dependabot::DependencyFileNotParseable.new(vendir_yml.path, msg)
          end
        end
      end
    end
  end
end