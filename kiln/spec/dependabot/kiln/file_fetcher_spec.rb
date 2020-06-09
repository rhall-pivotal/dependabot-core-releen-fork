# frozen_string_literal: true

require "spec_helper"
require "dependabot/kiln/file_fetcher"
require_common_spec "file_fetchers/shared_examples_for_file_fetchers"

RSpec.describe Dependabot::Kiln::FileFetcher, :vcr do
  it_behaves_like "a dependency file fetcher"

  let(:repo) { "dependabot-fixtures/kiln-lib" }
  let(:branch) { "master" }
  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: repo,
      directory: directory,
      branch: branch
    )
  end
  let(:file_fetcher_instance) do
    described_class.new(source: source, credentials: github_credentials)
  end
  let(:directory) { "/" }

  it "fetches the Kilnfile and Kilnfile.lock" do
    expect(file_fetcher_instance.files.map(&:name)).
      to include("Kilnfile", "Kilnfile.lock")
  end

  context "without a Kilnfile" do
    let(:branch) { "without-Kilnfile" }

    it "raises a helpful error" do
      expect { file_fetcher_instance.files }.
        to raise_error(Dependabot::DependencyFileNotFound)
    end
  end

  context "without a Kilnfile.lock" do
    let(:branch) { "without-Kilnfile-lock" }

    it "doesn't raise an error" do
      expect { file_fetcher_instance.files }.to_not raise_error
    end
  end

  context "for an application" do
    let(:repo) { "dependabot-fixtures/kiln-app" }

    it "fetches the main.go, too" do
      expect(file_fetcher_instance.files.map(&:name)).
        to include("main.go")
      expect(file_fetcher_instance.files.
        find { |f| f.name == "main.go" }.type).to eq("package_main")
    end
  end
end
