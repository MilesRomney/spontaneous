# encoding: UTF-8


module Spontaneous
  module Generators
    class Page < Generator
      def self.banner; "spot generate page [page_type | PageType]"; end


    def class_name
      case type_name
      when /^[A-Z]/
        type_name
      else
        type_name.camelize
      end
    end

    def disk_name
      case type_name
      when /^[A-Z]/
        type_name.underscore
      else
        type_name
      end
    end

    argument :type_name, :type => :string, :desc => "The name for this page type (page_type_name OR PageTypeName)"
      desc "Generates a new page type"
      def generate_page
        self.destination_root = options[:root]
        empty_directory "schema"
        template 'page.rb.tt', "schema/#{disk_name}.rb"
        copy_file 'inline.html.cut', "templates/#{disk_name}.html.#{Spontaneous::Output::Template.extension}"
      end
    end
  end
end
