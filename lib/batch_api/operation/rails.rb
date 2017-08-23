require 'batch_api/operation/rack'

module BatchApi
  # Public: an individual batch operation.
  module Operation
    class Rails < Operation::Rack
      # Public: create a new Rails Operation.  It does all that Rack does
      # and also some additional Rails-specific processing.
      # def initialize(op, base_env, app)
      #   super
      #   @params = params_with_path_components
      #   @params_with
      # end

      # Internal: customize the request environment.  This is currently done
      # manually and feels clunky and brittle, but is mostly likely fine, though
      # there are one or two environment parameters not yet adjusted.
      def process_env
        # parameters
        super
        @env["action_dispatch.request.parameters"] = params_with_path_components
        @env["action_dispatch.request.request_parameters"] = @params
        if (@method == "get")
          @env['CONTENT_TYPE'] = nil
          env["action_dispatch.request.content_type"] = nil
        end
      end

      private

      # Internal: process the params the Rails way, merging in the
      # path_parameters.  If the route can't be recognized, it will
      # leave the params unchanged.
      #
      # Returns the updated params.
      def params_with_path_components
        begin
          path_params = ::Rails.application.routes.recognize_path(@url, @op)
          @params.merge(path_params)
        rescue
          @params
        end
      end
    end
  end
end

