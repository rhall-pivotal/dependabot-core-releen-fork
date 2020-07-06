# frozen_string_literal: true

require "spec_helper"
require "dependabot/vendir"
require_common_spec "shared_examples_for_autoloading"

RSpec.describe Dependabot::Vendir do
  it_behaves_like "it registers the required classes", "vendir"
end