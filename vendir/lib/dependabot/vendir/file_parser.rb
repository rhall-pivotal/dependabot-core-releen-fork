# frozen_string_literal: true

require "yaml"

require "dependabot/dependency"
require "dependabot/file_parsers/base/dependency_set"
require "dependabot/file_parsers"
require "dependabot/file_parsers/base"
require "dependabot/errors"
require 'pp'

module Dependabot
  module Vendir
    class FileParser < Dependabot::FileParsers::Base
      def parse
        dependency_set = Dependabot::FileParsers::Base::DependencySet.new

        json = YAML.safe_load(vendir_lock_yml.content, aliases: true)
        directories = json.fetch("directories")
        locked_deps = deep_fetch_dependencies(directories, []).uniq

        json = YAML.safe_load(vendir_yml.content, aliases: true)
        directories = json.fetch("directories")
        deps = deep_fetch_dependencies(directories, []).uniq

        deps.zip(locked_deps)
            .each do |d|
          dep = handle_paths(d)
          dependency_set << dep if dep
        end

        dependency_set.dependencies

        #module_info
      rescue NoMethodError
        raise Dependabot::DependencyFileNotParseable, vendir_yml.path
      end

      private

      def deep_fetch_dependencies(json_obj, ancestors)
        path = ancestors.dup
        case json_obj
        when Hash then deep_fetch_dependencies_from_hash(json_obj, path)
        when Array then json_obj.flat_map { |o| deep_fetch_dependencies(o, path) }
        else []
        end
      end

      def deep_fetch_dependencies_from_hash(json_object, ancestors)
        parent_path = ancestors.dup
        path = parent_path.push(json_object.fetch("path", []))

        type = json_object.key?("contents") ? "contents" :
          json_object.key?("git") ? "git" :
          json_object.key?("githubRelease") ? "githubRelease" :
          json_object.key?("directory") ? "directory" :
          json_object.key?("manual") ? "manual" : "unsupported"

        if type.eql?("contents") then
          deep_fetch_dependencies(json_object.fetch("contents"), path)
        else
          { :type => type, :path => path, json_object: json_object }
        end
      end

      def handle_paths(d)
        req, lock = d

        type = req[:type]
        path = req[:path]
        raise Dependabot::DependencyFileNotParseable.new(vendir_yml.path,
          "Dependency #{path} does not match path #{lock[:path]}") unless type.eql?(lock[:type]) and path.eql?(lock[:path])

        case type
        when "git"
          handle_git(path, req, lock)
        when "githubRelease"
          handle_githubRelease(path, req, lock)
        end
      end

      def handle_git(path, req, lock)
        req_json_object = req[:json_object].fetch("git", [])
        lock_json_object = lock[:json_object].fetch("git", [])
        url = req_json_object.fetch("url", [])
        ref = req_json_object.fetch("ref", [])
        branch = ref
        if req_json_object.key?("refSelection")
          if req_json_object.fetch("refSelection").key?("semver")
            semver = req_json_object.fetch("refSelection").fetch("semver")
            ref = semver["constraints"]
            branch = ""
          end
        end

        lock_ref = lock_json_object.fetch("sha", [])

        Dependency.new(
          name: path.join("/"),
          version: lock_ref,
          requirements: [{
            requirement: ref,
            groups: [],
            source: {
              type: "git",
              branch: branch,
              ref: ref,
              url: url,
              path: path,
            },
            file: vendir_yml.path,
          }],
          package_manager: "vendir"
        )
      end

      def handle_githubRelease(path, req, lock)
        req_json_object = req[:json_object].fetch("githubRelease", [])
        lock_json_object = lock[:json_object].fetch("githubRelease", [])
        slug = req_json_object.fetch("slug", [])
        tag = req_json_object.fetch("tag", [])
        lock_url = lock_json_object.fetch("url", [])

        Dependency.new(
          name: path.join("/"),
          version: lock_url,
          requirements: [{
            requirement: tag,
            groups: [],
            source: {
              type: "githubRelease",
              slug: slug,
              tag: tag,
              path: path
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
        raise "No vendir.lock.yml!" unless vendir_lock_yml
      end
    end
  end
end

Dependabot::FileParsers.
  register("vendir", Dependabot::Vendir::FileParser)
