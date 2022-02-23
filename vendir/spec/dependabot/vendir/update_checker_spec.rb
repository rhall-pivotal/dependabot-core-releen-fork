# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/vendir/update_checker"
require_common_spec "update_checkers/shared_examples_for_update_checkers"

RSpec.describe Dependabot::Vendir::UpdateChecker do
  it_behaves_like "an update checker"

  describe "update dependencies" do
    context "dependency using ref selection" do
      let(:dependency_name) { "uaa" }
      let(:current_version) { "74.16.0" }
      let(:requirements) {
        [{
           requirement: ">=2.36.0",
           file: "/vendir.yml",
           source: {
             type: "git",
             branch: "",
             ref: ">=2.36.0",
             url: "https://github.com/cloudfoundry/cf-networking-release",
             remote_path: [".test", "nats"]
           },
           groups: []
         }]
        }
      let(:updated_requirements) {
        [{
           requirement: "3.0.0",
           file: "/vendir.lock.yml",
           source: {
             type: "git",
             branch: "3.0.0",
             ref: "3.0.0",
             url: "https://github.com/cloudfoundry/cf-networking-release",
             remote_path: [".test", "nats"]
           },
           groups: []
         }]
      }

      context "with a version that exists" do

        it { is_expected.to eq(updated_requirements) }
      end
    end
  end
end
