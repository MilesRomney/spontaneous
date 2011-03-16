
module Spontaneous
  module Rack
    class Static
      def initialize(app, options)
        @app = app
        @try = ['', *options.delete(:try)].compact
        @static = ::Rack::Static.new(
          lambda { [404, {}, []] },
          options)
      end

      def call(env)
        orig_path = env['PATH_INFO']
        found = nil
        @try.each do |path|
          resp = @static.call(env.merge!({'PATH_INFO' => orig_path + path}))
          break if 404 != resp[0] && found = resp
        end
        if found
          puts "found static"
          p found
        end
        found or @app.call(env.merge!('PATH_INFO' => orig_path))
      end

    end
  end
end
