# frozen_string_literal: true

################################################################################
# For more details on vendir version constraints, see:                             #
# - https://github.com/Masterminds/semver                                      #
# - https://github.com/golang/dep/blob/master/docs/Gopkg.toml.md               #
################################################################################

require "dependabot/utils"

module Dependabot
    module Vendir
      class Requirement < Gem::Requirement
      end
    end
end

Dependabot::Utils.
  register_requirement_class("vendir", Dependabot::Vendir::Requirement)
