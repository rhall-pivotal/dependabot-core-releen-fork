# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_file"
require "dependabot/source"
require "dependabot/dependency"
require "dependabot/vendir/file_parser"
require_common_spec "file_parsers/shared_examples_for_file_parsers"

RSpec.describe Dependabot::Vendir::FileParser do
  it_behaves_like "a dependency file parser"

  let(:parser) { described_class.new(dependency_files: files, source: source) }
  let(:files) { [vendir_yml, vendir_lock_yml] }
  let(:vendir_yml) do
    Dependabot::DependencyFile.new(
      name: "vendir.yml",
      content: vendir_yml_content
    )
  end
  let(:vendir_yml_content) { fixture("vendir_ymls", vendir_yml_fixture_name) }
  let(:vendir_yml_fixture_name) { "vendir.yml" }

  let(:vendir_lock_yml) do
    Dependabot::DependencyFile.new(
      name: "vendir.lock.yml",
      content: vendir_lock_yml_content
    )
  end
  let(:vendir_lock_yml_content) { fixture("vendir_lock_ymls", vendir_lock_yml_fixture_name) }
  let(:vendir_lock_yml_fixture_name) { "vendir.lock.yml" }

  let(:source) do
    Dependabot::Source.new(
      provider: "github",
      repo: "releen/vendir-fixtures",
      directory: "/"
    )
  end

  it "requires a vendir.yml to be present" do
    expect do
      described_class.new(dependency_files: [], source: source)
    end.to raise_error(RuntimeError)
  end

  describe "parse" do
    subject(:dependencies) { parser.parse }

    its(:length) { is_expected.to eq(9) }

    describe "parse for refSelection" do
      subject(:dependency) do
        dependencies.find { |d| d.name == "config/_ytt_lib/github.com/cloudfoundry/cf-networking-release" }
      end

      it "sets the right details" do
        expect(dependency.requirements).to eq(
                                             [{
                                                requirement: ">=2.36.0",
                                                file: vendir_yml.path,
                                                groups: [],
                                                source: {
                                                  type: "git",
                                                  url: "https://github.com/cloudfoundry/cf-networking-release",
                                                  branch: ">=2.36.0"
                                                },
                                                ref: ">=2.36.0"
                                              }]
                                           )
      end
    end

    describe "top level dependencies" do
      subject(:dependencies) do
        parser.parse.select(&:top_level?)
      end

      it "sets the package manager" do
        expect(dependencies.first.package_manager).to eq("vendir")
      end

      describe "a git dependency" do
        subject(:dependency) do
          dependencies.find { |d| d.name == "config/_ytt_lib/github.com/cloudfoundry/cf-k8s-networking" }
        end

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("config/_ytt_lib/github.com/cloudfoundry/cf-k8s-networking")
          puts dependency.inspect
          expect(dependency.version).to eq("4153bbdbaf3e8d3d681a84a112f3c9cc10129ff3")
          expect(dependency.requirements).to eq(
            [{
              requirement: "v0.0.6",
              file: vendir_yml.path,
              groups: [],
              source: {
                type: "git",
                url: "https://github.com/cloudfoundry/cf-k8s-networking",
                branch: "v0.0.6"
              }
            }]
          )
        end
      end

      describe "a githubRelease dependency" do
        subject(:dependency) do
          dependencies.find { |d| d.name == "config/_ytt_lib/github.com/cloudfoundry/cf-k8s-logging/config" }
        end

        it "has the right details" do
          expect(dependency).to be_a(Dependabot::Dependency)
          expect(dependency.name).to eq("config/_ytt_lib/github.com/cloudfoundry/cf-k8s-logging/config")
          expect(dependency.version).to eq("https://api.github.com/repos/cloudfoundry/cf-k8s-logging/releases/26725288")
          expect(dependency.requirements).to eq(
            [{
              requirement: "0.2.1",
              file: vendir_yml.path,
              groups: [],
              source: {
                type: "githubRelease",
                slug: "cloudfoundry/cf-k8s-logging",
                tag: "0.2.1"
              }
            }]
          )
        end
      end
    end

    describe "a garbage vendir.yml" do
      let(:vendir_yml_content) { "not really a vendir.yml file :-/" }

      it "raises the correct error" do
        expect { parser.parse }.
          to raise_error(Dependabot::DependencyFileNotParseable) do |error|
            expect(error.file_path).to eq("/vendir.yml")
          end
      end
    end

    # describe "a non-existent dependency" do
    #   let(:vendir_yml_content) do
    #     vendir_yml = fixture("vendir_ymls", vendir_yml_fixture_name)
    #     vendir_yml.sub("https://github.com/cloudfoundry/cf-k8s-networking", "https://github.com/example.com/not-a-repo")
    #   end

    #   it "raises the correct error" do
    #     expect { parser.parse }.
    #       to raise_error(Dependabot::DependencyFileNotResolvable)
    #   end
    # end

    # describe "a dependency at a non-existent version" do
    #   let(:vendir_yml_content) do
    #     vendir_yml = fixture("vendir_ymls", vendir_yml_fixture_name)
    #     vendir_yml.sub("ref: v0.0.6", "ref: v999.999.9999")
    #   end

    #   it "raises the correct error" do
    #     expect { parser.parse }.
    #       to raise_error(Dependabot::DependencyFileNotResolvable)
    #   end
    # end
  end
end