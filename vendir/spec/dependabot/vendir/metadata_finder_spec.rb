# frozen_string_literal: true

require "octokit"
require "spec_helper"
require "dependabot/dependency"
require "dependabot/vendir/metadata_finder"
require_common_spec "metadata_finders/shared_examples_for_metadata_finders"

RSpec.describe Dependabot::Vendir::MetadataFinder do
  it_behaves_like "a dependency metadata finder"
end