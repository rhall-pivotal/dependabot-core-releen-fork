# frozen_string_literal: true

require "dependabot/file_updaters"
require "dependabot/file_updaters/base"

module Dependabot
  module Vendir
    class FileUpdater < Dependabot::FileUpdaters::Base
      def updated_dependency_files
        updated_files = []

        if vendir_yml && file_changed?(vendir_yml)
          updated_files <<
            updated_file(
              file: vendir_yml,
              content: file_updater.updated_vendir_yml_content
            )

          if vendir_lock_yml && vendir_lock_yml.content != file_updater.updated_vendir_lock_yml_content
            updated_files <<
              updated_file(
                file: vendir_lock_yml,
                content: file_updater.updated_vendir_lock_yml_content
              )
          end
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
        %w(vendir.yml).each do |filename|
          raise "No #{filename}!" unless get_original_file(filename)
        end
      end   
    end
  end
end

Dependabot::FileUpdaters.
  register("vendir", Dependabot::Vendir::FileUpdater)