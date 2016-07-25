module NiftyServices
  module Concerns
  end

  class BaseCrudService < BaseService
    attr_reader :record

    class << self
      def record_type(record_type, options = {})
        define_method :record_type do
          record_type
        end

        record_alias = options.delete(:alias_name)
        record_alias ||= record_type.to_s.underscore

        alias_method record_alias.to_sym, :record
      end

      def include_concern(namespace, concern_type)
        module_name = "#{services_concern_namespace}::
                       #{namespace.to_s.camelize}::
                       #{concern_type.to_s.camelize}"

        self.include(module_name.constantize)
      end

      def services_concern_namespace
        NiftyServices.config.service_concerns_namespace
      end

      alias concern include_concern
    end

    def initialize(record, user, options = {})
      @record = record
      @user = user

      super(options)
    end

    def changed_attributes
      []
    end

    def changed?
      changed_attributes.any?
    end

    def record_type
      not_implemented_exception(__method__)
    end

    def record_attributes_hash
      not_implemented_exception(__method__)
    end

    def record_attributes_whitelist
      not_implemented_exception(__method__)
    end

    def record_allowed_attributes
      filter_hash(record_attributes_hash, record_attributes_whitelist)
    end

    alias record_safe_attributes record_allowed_attributes

    private

    def invalid_user_error_key
      %s(users.not_found)
    end

    def validate_user?
      true
    end

    def array_values_from_string(string)
      string.to_s.split(/\,/).map(&:squish)
    end

    def record_error_key
      record_type.to_s.pluralize.underscore
    end

    def valid_record?
      valid_object?(@record, record_type)
    end
  end
end
