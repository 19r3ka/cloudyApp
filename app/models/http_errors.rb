module HttpErrors

  # This is the standard error raised by handling http response code
  class CloudError < RuntimeError
    attr_accessor :http_status, :error_message
    def initialize(error_message, http_status=nil)
      @error_message = error_message
      @http_status   = http_status
    end
  end

  # Error raised on Authentification failure
  # Error code: 401
  # 1. User did not approve the app
  # 2. User disapprove the app at some point
  # 3. Session has an invalid token
  # Send the user back to redirection url
  class AuthError < CloudError; end

  # Error raised when there is no change to the last call to metadata
  # Used to implement local caching
  class ItemNameInUse < CloudError; end

  # Missing item
  # Error code: 404
  class ObjectNotFound < StandardError; end

  # Raised when the request has a problem
  # Error code: 400, 403, 405
  class RequestError < CloudError; end

  # Something went wrong with the distant server (out of our control)
  # Error code: 5xx
  class ServerError < CloudError; end
end