# encoding: UTF-8

module Spontaneous
  module Constants
    EMPTY = "".freeze
    SLASH = "/".freeze
    DASH = "-".freeze
    AMP = "&".freeze
    DOT = ".".freeze
    QUESTION = "?".freeze
    LF = "\n".freeze

    RE_QUOTES = /['"]/.freeze
    RE_FLATTEN = /[^\.a-z0-9-]+/.freeze
    RE_FLATTEN_REPEAT = /\-+/.freeze
    RE_FLATTEN_TRAILING = /(^\-|\-$)/.freeze
  end
end