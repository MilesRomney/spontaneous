# encoding: UTF-8

module Spontaneous::Field
  class Tags < Base
    # Just use the standard String editor for now.
    # TODO: This should be replaced with a tags specific one asap.
    has_editor "Spontaneous.Field.String"

    include Enumerable

    def outputs
      [:html, :tags]
    end

    def generate_html(value, site)
      value
    end

    TAG_PARSER_RE = /"([^"]+)"|([^ ]+)/

    def generate_tags(value, site)
      return [] if value.blank?
      (value).scan(TAG_PARSER_RE).flatten.compact
    end

    def taglist
      values[:tags] || []
    end

    def each(&block)
      taglist.each(&block)
    end

    self.register
  end
end
