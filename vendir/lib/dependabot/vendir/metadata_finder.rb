# frozen_string_literal: true

require "dependabot/metadata_finders"
require "dependabot/metadata_finders/base"

module Dependabot
  module Vendir
    class MetadataFinder < Dependabot::MetadataFinders::Base

      private

      def look_up_source
        url = dependency.requirements.first.fetch(:source)[:url] ||
              dependency.requirements.first.fetch(:source).fetch("url")

        Source.from_url(url) if url
      end
    end
  end
end

Dependabot::MetadataFinders.
  register("vendir", Dependabot::Vendir::MetadataFinder)
