module NiftyServices
  class Error < RuntimeError
  end

  module Errors
    Configuration::ERROR_RESPONSE_STATUS.each do |error, _status|
      class_eval <<-END
        class #{error.to_s.camel_case} < Error
        end
      END
    end

    class InvalidUser < Error
      MESSAGE = 'Invalid User class.
                 Use NiftyServices.config.user_class = ClassName'.freeze

      def initialize
        super(MESSAGE)
      end
    end
  end
end
