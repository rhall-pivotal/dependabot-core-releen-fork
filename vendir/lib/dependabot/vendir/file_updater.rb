# frozen_string_literal: true

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"

module Dependabot
  module Vendir
    class FileUpdater < Dependabot::FileUpdaters::Base
      require_relative "file_updater/vendir_updater"

      def updated_dependency_files
        updated_files = []

        if vendir_yml && file_changed?(vendir_yml)
          updated_files <<
            updated_file(
              file: vendir_yml,
              content: file_updater.updated_vendir_yml_content
            )
        end

        if vendir_lock_yml && vendir_lock_yml.content != file_updater.updated_vendir_lock_yml_content
          updated_files <<
            updated_file(
              file: vendir_lock_yml,
              content: file_updater.updated_vendir_lock_yml_content
            )
        end

        raise "No files changed!" if updated_files.none?

        updated_files
      end

      def self.updated_files_regex
        [
          /^vendir\.yml$/,
          /^vendir\.lock\.yml$/
        ]
      end

      private

      def check_required_files
        %w(vendir.yml vendir.lock.yml).each do |filename|
          raise "No #{filename}!" unless get_original_file(filename)
        end
      end

      def vendir_yml
        @vendir_yml ||= get_original_file("vendir.yml")
      end

      def vendir_lock_yml
        @vendir_lock_yml ||= get_original_file("vendir.lock.yml")
      end

      def file_updater
        @file_updater ||=
          VendirUpdater.new(
            dependencies: dependencies,
            vendir_yml: vendir_yml,
            vendir_lock_yml: vendir_lock_yml,
            credentials: credentials
          )
      end
    end
  end
end

Dependabot::FileUpdaters.
  register("vendir", Dependabot::Vendir::FileUpdater)