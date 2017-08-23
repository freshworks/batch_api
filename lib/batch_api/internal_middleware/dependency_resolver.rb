require 'liquid'
module BatchApi
  module InternalMiddleware
    
    class DependencyResolver
      SUCCESS_CODES = (200..299).freeze
      # Public: initialize the middleware.
      def initialize(app)
        @app = app
      end

      def call(env)
        op = env[:op]
        if op.depends_on.any?
          begin
            resolve_dependencies(op, env[:results])
          rescue BatchApi::Errors::DependencyError => e
            return BatchApi::Response.new([e.status_code, {"Content-Type" => "application/json"}, [{ "error" => e.message }.to_json]])
          end
        end
        @app.call(env)
      end

      private

      def resolve_dependencies(op, json_results)
        if op.depends_on.detect { |d_on| json_results[d_on][:errors] }
          raise BatchApi::Errors::DependencyRequestFailedError
        end
        begin
          op.url = Liquid::Template.parse(op.url).render!('data' => json_results)
          op.params = JSON.parse(Liquid::Template.parse(op.params.to_json).render!('data' => json_results))
          op.headers = JSON.parse(Liquid::Template.parse(op.headers.to_json).render!('data' => json_results))
        rescue Exception => e 
          raise BatchApi::Errors::DependencyPlaceholderError
        end
      end
    end
  end
end
