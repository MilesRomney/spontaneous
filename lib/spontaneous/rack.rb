# encoding: UTF-8

require "rack"
require "sinatra"
require 'sinatra/base'

module Spontaneous
  module Rack
    class << self
      def application
        case Spontaneous.mode
        when :back
          Back.application
        when :front
          Front.application
        end
      end

      def port
        Spontaneous.config[Spontaneous.mode][:port]
      end
    end

    class ServerBase < ::Sinatra::Base
      set :environment, Proc.new { Spontaneous.environment }

      # serve static files from the app's public dir

      mime_type :js,  'text/javascript; charset=utf-8'
      mime_type :css, 'text/css; charset=utf-8'

      before do
        content_type 'text/html', :charset => 'utf-8'
        if Spontaneous.development?
          Templates.clear_cache!
        end
      end
    end

    autoload :Back, 'spontaneous/rack/back'
    autoload :Front, 'spontaneous/rack/front'
    autoload :Public, 'spontaneous/rack/public'
  end
end

