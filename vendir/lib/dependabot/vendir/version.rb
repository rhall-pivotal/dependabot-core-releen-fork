require "dependabot/utils"

module Dependabot
  module Vendir
    class Version < Gem::Version
    end
  end
end

Dependabot::Utils.
  register_version_class("vendir", Dependabot::Vendir::Version)