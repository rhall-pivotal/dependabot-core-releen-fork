# frozen_string_literal: true

# These all need to be required so the various classes can be registered in a
# lookup table of package manager names to concrete classes.
require "dependabot/vendir/file_fetcher"
require "dependabot/vendir/file_parser"
require "dependabot/vendir/update_checker"
require "dependabot/vendir/file_updater"
require "dependabot/vendir/metadata_finder"
require "dependabot/vendir/requirement"
require "dependabot/vendir/version"

require "dependabot/pull_request_creator/labeler"
Dependabot::PullRequestCreator::Labeler.
  register_label_details("vendir", name: "vendir", colour: "1600e2")

require "dependabot/dependency"
Dependabot::Dependency.
  register_production_check("vendir", ->(_) { true })