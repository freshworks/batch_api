require 'batch_api/response'

module BatchApi
  # Public: an individual batch operation.
  module Operation
    class Rack
      attr_accessor :method, :url, :params, :headers, :depends_on
      attr_accessor :env, :app, :result, :options

      # Public: create a new Batch Operation given the specifications for a batch
      # operation (as defined above) and the request environment for the main
      # batch request.
      def initialize(op, base_env, app, index = 0)
        @op = op

        @method = op["method"] || "get"
        @url = op["url"]
        @params = op["params"] || {}
        @headers = op["headers"] || {}
        @depends_on = op["depends_on"] || []
        @options = op

        raise Errors::MalformedOperationError,
          "BatchAPI operation must include method (received #{@method.inspect}) " +
          "and url (received #{@url.inspect})" unless @method && @url
        raise Errors::MalformedOperationError,
          "depends_on must be an array of integers and must depend on previous requests" unless (@depends_on.is_a?(Array) &&
            !@depends_on.detect{|d| !d.is_a?(Integer) || d >= index || d < 0})

        @app = app
        # deep_dup to avoid unwanted changes across requests
        @env = BatchApi::Utils.deep_dup(base_env)
      end

      # Execute a batch request, returning a BatchResponse object.  If an error
      # occurs, it returns the same results as Rails would.
      def execute
        process_env
        begin
          response = @app.call(@env)
        rescue => err
          response = BatchApi::ErrorWrapper.new(err).render
        end
        BatchApi::Response.new(response)
      end

      # Internal: customize the request environment.  This is currently done
      # manually and feels clunky and brittle, but is mostly likely fine, though
      # there are one or two environment parameters not yet adjusted.
      def process_env
        path, qs = @url.split("?")

        # Headers
        headrs = (@headers || {}).inject({}) do |heads, (k, v)|
          heads.tap {|h| h["HTTP_" + k.gsub(/\-/, "_").upcase] = v}
        end
        # preserve original headers unless explicitly overridden
        @env.merge!(headrs)

        # method
        @env["REQUEST_METHOD"] = @method.upcase

        # path and query string
        if @env["REQUEST_URI"]
          # not all servers provide REQUEST_URI -- Pow, for instance, doesn't
          @env["REQUEST_URI"] = @env["REQUEST_URI"].gsub(/#{BatchApi.config.endpoint}.*/, @url)
        end
        @env["REQUEST_PATH"] = path
        @env["ORIGINAL_FULLPATH"] = @env["PATH_INFO"] = @url

        @env["rack.request.query_string"] = qs
        @env["QUERY_STRING"] = qs

        # parameters
        @env["rack.request.form_hash"] = @params
        @env["rack.request.query_hash"] = @method == "get" ? @params : nil
      end
    end
  end
end
