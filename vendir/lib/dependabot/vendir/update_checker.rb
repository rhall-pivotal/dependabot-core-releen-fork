# frozen_string_literal: true

require "dependabot/update_checkers"
require "dependabot/update_checkers/base"
require "dependabot/shared_helpers"
require "dependabot/errors"

module Dependabot
    module Vendir
      class UpdateChecker < Dependabot::UpdateCheckers::Base
      end
    end
end

Dependabot::UpdateCheckers.
  register("vendir", Dependabot::Vendir::UpdateChecker)