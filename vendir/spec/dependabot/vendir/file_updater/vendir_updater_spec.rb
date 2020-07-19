# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/vendir/file_updater/vendir_updater"

RSpec.describe Dependabot::Vendir::FileUpdater::VendirUpdater do
  let(:updater) do
    described_class.new(
      vendir_yml: vendir_yml,
      vendir_lock_yml: vendir_lock_yml,
      dependencies: [dependency],
      credentials: [{
        "type" => "git_source",
        "host" => "github.com",
        "username" => "x-access-token",
        "password" => "token"
      }]
    )
  end

  let(:vendir_yml) do
    Dependabot::DependencyFile.new(name: "vendir.yml", content: vendir_yml_body)
  end
  let(:vendir_yml_body) { fixture("vendir_ymls", vendir_yml_fixture_name) }
  let(:vendir_yml_fixture_name) { "vendir.yml" }

  let(:vendir_lock_yml) do
    Dependabot::DependencyFile.new(name: "vendir.lock.yml", content: vendir_lock_yml_body)
  end
  let(:vendir_lock_yml_body) { fixture("vendir_lock_ymls", vendir_lock_yml_fixture_name) }
  let(:vendir_lock_yml_fixture_name) { "vendir.lock.yml" }

  let(:dependency) do
    Dependabot::Dependency.new(
      name: dependency_name,
      version: dependency_version,
      requirements: requirements,
      previous_version: dependency_previous_version,
      previous_requirements: previous_requirements,
      package_manager: "vendir"
    )
  end


  describe "#updated_vendir_lock_yml_content" do
    subject(:updated_vendir_lock_yml_content) { updater.updated_vendir_lock_yml_content }

    let(:dependency_name) { "config/_ytt_lib/github.com/cloudfoundry/capi-k8s-release" }
    let(:dependency_version) { "5fb4c89475b347fce449068e9f260732a0e43d74" }
    let(:dependency_previous_version) { "5fb4c89475b347fce449068e9f260732a0e43d74" }
    let(:requirements) { previous_requirements }
    let(:previous_requirements) do
        [{
          file: "vendir.yml",
          requirement: "master",
          groups: [],
          source: {
            type: "git",
            source: "git@github.com:cloudfoundry/capi-k8s-release",
            path: ["config/_ytt_lib", "github.com/cloudfoundry/capi-k8s-release"]
          }
        }]
      end

    context "if no files have changed" do
        it { is_expected.to eq(vendir_lock_yml.content) }
    end

    context "when the requirement has changed" do
        let(:dependency_version) { "39cc43dde1b86714f6a3fe97d01dab07c9cc1038" }
        let(:requirements) do
          [{
            file: "vendir.yml",
            requirement: "39cc43dde1b86714f6a3fe97d01dab07c9cc1038",
            groups: [],
            source: {
              type: "git",
              source: "git@github.com:cloudfoundry/capi-k8s-release",
              path: ["config/_ytt_lib", "github.com/cloudfoundry/capi-k8s-release"]
            }
          }]
        end

        it { is_expected.to include(%(5fb4c89475b347fce449068e9f260732a0e43d74\n)) }
    end
  end
end