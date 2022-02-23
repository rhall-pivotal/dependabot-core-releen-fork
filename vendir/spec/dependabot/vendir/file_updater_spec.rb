# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency"
require "dependabot/dependency_file"
require "dependabot/vendir/file_updater"
require_common_spec "file_updaters/shared_examples_for_file_updaters"

RSpec.describe Dependabot::Vendir::FileUpdater do
  it_behaves_like "a dependency file updater"
  context "with a new component version available" do
    it "makes a PR to update Vendir.lock" do
      vendir_dir = File.dirname(File.dirname(File.dirname(__FILE__)))
      script_path = File.join(vendir_dir, "update_script", "update.rb")
      stdout, stderr, status = Open3.capture3({
                                                "DEPENDABOT_TARGET_REPO" => repo_name,
                                                "DEPENDABOT_TARGET_REPO_BRANCH" => repo_branch,
                                                "DEPENDABOT_TARGET_REPO_DIRECTORIES" => "update_integration_spec/upgrade",
                                                "GITHUB_RELENG_CI_BOT_PERSONAL_ACCESS_TOKEN" => github_token,
                                                "S3_ACCESS_KEY_ID" => s3_access_key_id,
                                                "S3_SECRET_ACCESS_KEY" => s3_secret_access_key,
                                              }, "bundler exec ruby #{script_path}")
      puts stdout
      puts stderr
      expect(status.exitstatus).to eq(0)

      pull_requests = github_client.pull_requests(repo_name, :state => 'open', :base => repo_branch)
      expect(pull_requests.map(&:title)).to include(match(pr_title))
    end
  end
end
