# frozen_string_literal: true

require "yaml"

require "dependabot/dependency"
require "dependabot/file_parsers/base/dependency_set"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/errors"

module Dependabot
  module Vendir
    class FileParser < Dependabot::FileParsers::Base
      def parse
        dependency_set = Dependabot::FileParsers::Base::DependencySet.new

        json = YAML.safe_load(vendir_yml.content, aliases: true)
        directories = json.fetch("directories")
        deps = deep_fetch_dependencies(directories).uniq

        deps.each do |dep|
          #puts dep.name
          dependency_set << dep if dep
        end

        module_info
        dependency_set.dependencies

      rescue NoMethodError
        raise Dependabot::DependencyFileNotParseable, vendir_yml.path
      end

      private

      def deep_fetch_dependencies(json_obj)
        case json_obj
        when Hash then deep_fetch_dependencies_from_hash(json_obj)
        when Array then json_obj.flat_map { |o| deep_fetch_dependencies(o) }
        else []
        end
      end

      def deep_fetch_dependencies_from_hash(json_object)
        path = json_object.fetch("path", [])

        type = json_object.key?("contents") ? "contents" : 
          json_object.key?("git") ? "git" : 
          json_object.key?("githubRelease") ? "githubRelease" :
          json_object.key?("directory") ? "directory" :
          json_object.key?("manual") ? "manual" : "unsupported"

        handle_paths(path, json_object, type)
      end      

      def handle_paths(path, json_object, type)
        #puts "#{path} is of type #{type}"
        case type
        when "contents"
          handle_contents(path, json_object.fetch("contents"))
        when "git"
          handle_git(path, json_object.fetch("git"))
        when "githubRelease"
          handle_githubRelease(path, json_object.fetch("githubRelease"))
        else []
        end
      end

      def handle_contents(path, json_object)
        deps = deep_fetch_dependencies(json_object)
        deps.flat_map { |dep|
          name = dep.name.eql?(".") ? path : "#{path}/#{dep.name}"
          Dependency.new(
            name: name,
            version: dep.version,
            requirements: dep.requirements,
            package_manager: dep.package_manager
          )
        }
      end

      def handle_git(path, json_object)
        url = json_object.fetch("url", [])
        ref = json_object.fetch("ref", [])

        Dependency.new(
          name: path,
          version: ref,
          requirements: [{
            requirement: nil,
            groups: [],
            source: {
              type: "git",
              url: url,
              ref: ref,
              branch: ref
            },
            file: vendir_yml.path,
          }],
          package_manager: "vendir"
        )
      end

      def handle_githubRelease(path, json_object)
        slug = json_object.fetch("slug", [])
        tag = json_object.fetch("tag", [])

        Dependency.new(
          name: path,
          version: tag,
          requirements: [{
            requirement: nil,
            groups: [],
            source: {
              type: "githubRelease",
              slug: slug,
              tag: tag
            },
            file: vendir_yml.path,
          }],
          package_manager: "vendir"
        )
      end

      def module_info
        @module_info ||=
          SharedHelpers.in_a_temporary_directory do |path|
            SharedHelpers.with_git_configured(credentials: credentials) do
              File.write("vendir.yml", vendir_yml.content)

              command = "vendir sync"

              stdout, stderr, status = Open3.capture3(command)
              handle_parser_error(path, stderr) unless status.success?
              stdout
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
      def handle_parser_error(path, stderr)
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

      def vendir_yml
        @vendir_yml ||= get_original_file("vendir.yml")
      end

      def vendir_lock_yml
        @vendir_lock_yml ||= get_original_file("vendir.lock.yml")
      end

      def check_required_files
        raise "No vendir.yml!" unless vendir_yml
      end
    end
  end
end

Dependabot::FileParsers.
  register("vendir", Dependabot::Vendir::FileParser)