# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/shared_helpers"
require "dependabot/errors"

module Dependabot
  module Vendir
    class UpdateChecker < Dependabot::UpdateCheckers::Base
      def initialize(dependency:, dependency_files:, credentials:,
                     ignored_versions: [], raise_on_ignored: false,
                     security_advisories: [],
                     requirements_update_strategy: nil,
                     github_client:)
        @dependency = dependency
        @dependency_files = dependency_files
        @credentials = credentials
        @requirements_update_strategy = requirements_update_strategy
        @ignored_versions = ignored_versions
        @raise_on_ignored = raise_on_ignored
        @security_advisories = security_advisories
        @github_client = github_client
        super(dependency: dependency, dependency_files: dependency_files, credentials: credentials,
              ignored_versions: ignored_versions, raise_on_ignored: raise_on_ignored,
              security_advisories: security_advisories, requirements_update_strategy: requirements_update_strategy)
      end

      def latest_version
        @latest_version ||= fetch_latest_version
      end

      def latest_resolvable_version
        latest_version
      end

      def latest_resolvable_version_with_no_unlock
        # Unsure how to model this for now
        latest_version
      end

      def updated_requirements
        if updated_source == dependency_source_details
          return dependency.requirements
        end

        dependency.requirements.map { |req| req.merge(source: updated_source) }
      end

      private

      def latest_version_resolvable_with_full_unlock?
        # Unsure how to model this for now
        false
      end

      def updated_dependencies_after_full_unlock
        raise NotImplementedError
      end

      def fetch_latest_version
        # TODO: Support githubRelease sources
        return unless git_dependency?

        fetch_latest_version_for_git_dependency
      end

      def fetch_latest_version_for_git_dependency
        unless git_commit_checker.pinned?
          return git_commit_checker.head_commit_for_current_branch
        end

        # If the dependency is pinned to a tag that looks like a version then
        # we want to update that tag. The latest version will then be the SHA
        # of the latest tag that looks like a version.
        if git_commit_checker.pinned_ref_looks_like_version? &&
          git_commit_checker.local_tag_for_latest_version
          latest_tag = git_commit_checker.local_tag_for_latest_version
          return latest_tag.fetch(:commit_sha)
        end

        # If the dependency is pinned to a commit SHA and the latest
        # version-like tag includes that commit then we want to update to that
        # version-like tag. We return a version (not a commit SHA) so that we
        # get nice behaviour in PullRequestCreator::MessageBuilder
        if git_commit_checker.pinned_ref_looks_like_commit_sha? &&
          (latest_tag = git_commit_checker.local_tag_for_latest_version) &&
          git_commit_checker.branch_or_ref_in_release?(latest_tag[:version])
          return latest_tag.fetch(:version)
        end

        # If the dependency is pinned to a tag that doesn't look like a
        # version or a commit SHA then there's nothing we can do.
        dependency.version
      end

      # rubocop:disable Metrics/PerceivedComplexity
      def updated_source
        # TODO: Support Docker sources
        return dependency_source_details unless git_dependency?

        # Update the git tag if updating a pinned version
        if git_commit_checker.pinned_ref_looks_like_version? &&
          (new_tag = git_commit_checker.local_tag_for_latest_version) &&
          new_tag.fetch(:commit_sha) != current_commit
          return dependency_source_details.merge(ref: new_tag.fetch(:tag))
        end

        # Update the git tag if updating a pinned commit
        if git_commit_checker.pinned_ref_looks_like_commit_sha? &&
          (latest_tag = git_commit_checker.local_tag_for_latest_version) &&
          git_commit_checker.branch_or_ref_in_release?(latest_tag[:version])
          return dependency_source_details.merge(ref: latest_tag.fetch(:tag))
        end

        # Otherwise return the original source
        dependency_source_details
      end

      # rubocop:enable Metrics/PerceivedComplexity

      def dependency_source_details
        sources =
          dependency.requirements.map { |r| r.fetch(:source) }.uniq.compact

        return sources.first if sources.count <= 1

        # If there are multiple source types, or multiple source URLs, then it's
        # unclear how we should proceed
        if sources.map { |s| [s.fetch(:type), s[:url]] }.uniq.count > 1
          raise "Multiple sources! #{sources.join(', ')}"
        end

        # Otherwise it's reasonable to take the first source and use that. This
        # will happen if we have multiple git sources with difference references
        # specified. In that case it's fine to update them all.
        sources.first
      end

      def current_commit
        git_commit_checker.head_commit_for_current_branch
      end

      def git_dependency?
        git_commit_checker.git_dependency?
      end

      def git_commit_checker
        # if we have a constraint but no determined branch,
        # figure out the appropriate branch and set it
        unless dependency.requirements.empty?
          requirement = dependency.requirements[0]
          if requirement[:source][:branch] == ""
            unless requirement.has_key?(:source)
              raise "Source missing from vendir requirement"
            end
            unless requirement[:source].has_key?(:ref)
              raise "Ref missing from vendir requirement"
            end

            current_ref = requirement[:source][:ref]

            all_tags = @github_client.tags
                                     .map { |tag| tag.name[0] == "v" ? tag.name[1..-1] : tag.name }
                                     .filter { |t| Gem::Version.correct?(t) }
                                     .sort_by { |t| Gem::Version.new(t) }
                                     .reverse

            if all_tags.empty?
              raise "no valid tags found for dependency #{dep.name}"
            end

            requirement_gem = Gem::Requirement.new(current_ref)
            new_version_tag = nil
            all_tags.each { |tag|
              if requirement_gem.satisfied_by?(Gem::Version.new(tag))
                new_version_tag = tag
                break
              end
            }

            dependency.requirements[0][:source][:branch] = new_version_tag
            dependency.requirements[0][:requirement] = new_version_tag
            dependency.requirements[0][:source][:ref] = new_version_tag
          end
        end

        @git_commit_checker ||= Dependabot::GitCommitChecker.new(
          dependency: dependency,
          credentials: credentials,
          ignored_versions: ignored_versions,
          raise_on_ignored: raise_on_ignored
        )
      end
    end
  end
end

Dependabot::UpdateCheckers.
  register("vendir", Dependabot::Vendir::UpdateChecker)
