# frozen_string_literal: true

require "spec_helper"
require "dependabot/vendir/file_fetcher"
require_common_spec "file_fetchers/shared_examples_for_file_fetchers"

RSpec.describe Dependabot::Vendir::FileFetcher, :vcr do
  it_behaves_like "a dependency file fetcher"

  let(:branch) { "master" }

  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "releen/vendir-fixtures",
      directory: directory,
      branch: branch
    )
  end

  let(:directory) { "/" }

  let(:file_fetcher_instance) do
    described_class.new(source: source, credentials: github_credentials)
  end


  context "for a vendir project" do
    context "without a vendir.yml" do
      let(:branch) { "without-vendir-yml" }

      it "raises a helpful error" do
        expect { file_fetcher_instance.files }.
            to raise_error(Dependabot::DependencyFileNotFound)
      end
    end

    context "without a vendir.lock.yml" do
      let(:branch) { "without-vendir-lock-yml" }

      it "raises a helpful error" do
        expect { file_fetcher_instance.files }.
            to raise_error(Dependabot::DependencyFileNotFound)
      end
    end

    it "fetches both vendir.yml and vendir.lock.yml" do
      expect(file_fetcher_instance.files.map(&:name)).
          to match_array(%w(vendir.lock.yml vendir.yml))
    end
  end
end