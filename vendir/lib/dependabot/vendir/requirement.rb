# frozen_string_literal: true

require "dependabot/utils"

module Dependabot
    module Vendir
      class Requirement < Gem::Requirement
      end
    end
end

Dependabot::Utils.
  register_requirement_class("vendir", Dependabot::Vendir::Requirement)
