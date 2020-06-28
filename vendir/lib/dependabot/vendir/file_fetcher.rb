# frozen_string_literal: true

require "dependabot/file_fetchers"
require "dependabot/file_fetchers/base"

module Dependabot
  module Vendir
    class FileFetcher < Dependabot::FileFetchers::Base
      def self.required_files_in?(filenames)
        (%w(vendir.yml vendir.lock.yml) - filenames).empty?
      end

      def self.required_files_message
        "Repo must contain both vendir.yml and vendir.lock.yml"
      end

      private

      def fetch_files
        fetched_files = []
        fetched_files << vendirfile if vendirfile
        fetched_files << vendirlockfile if vendirlockfile

        unless vendirfile
          raise(
            Dependabot::DependencyFileNotFound,
            File.join(directory, "vendir.yml")
          )
        end

        unless vendirlockfile
          raise(
            Dependabot::DependencyFileNotFound,
            File.join(directory, "vendir.lock.yml")
          )
        end

        fetched_files
      end

      def vendirfile
        @vendirfile ||= fetch_file_if_present("vendir.yml")
      end

      def vendirlockfile
        @vendirlockfile ||= fetch_file_if_present("vendir.lock.yml")
      end
    end
  end
end

Dependabot::FileFetchers.register("vendir", Dependabot::Vendir::FileFetcher)
