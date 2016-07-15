module NiftyServices
  class BaseService

    attr_reader :options, :response_status, :response_status_code, :errors

    CALLBACKS = [
      :after_initialize,
      :before_error,
      :after_error,
      :before_success,
      :after_success,
      :before_create,
      :after_create,
      :before_update,
      :after_update,
      :before_delete,
      :after_delete,
      :before_action,
      :after_action
    ].freeze

    @@registered_callbacks = Hash.new {|k,v| k[v] = Hash.new  }

    class << self
      def register_callback(callback_name, method_name, &block)
        method_name = "#{method_name.to_s.gsub(/\Z_callback/, '')}_callback"

        @@registered_callbacks[self.name.to_sym][callback_name] ||= []
        @@registered_callbacks[self.name.to_sym][callback_name] << method_name

        register_callback_action(method_name, &block)
      end

      def register_callback_action(callback_name, &block)
        define_method(callback_name, &block)
      end

      def register_error_response_method(reason_string, status_code)
        NiftyServices::Configuration.add_response_error_method(reason_string, status_code)
        define_error_response_method(reason_string, status_code)
      end

      def define_error_response_method(reason_string, status_code)
        method_name = "#{reason_string.to_s.gsub(/\Z_error/, '')}_error"

        define_method method_name do |message_key, options = {}|
          error(status_code, message_key, options)
        end

        define_method "#{method_name}!" do |message_key, options = {}|
          error!(status_code, message_key, options)
        end
      end
    end

    CALLBACKS.each do |callback_name|
      # empty method call (just returns nil)
      define_method callback_name, -> {}
    end

    def initialize(options = {}, initial_response_status = 400)
      @options = options.to_options!
      @errors = []

      set_response_status(initial_response_status)
      initial_callbacks_setup

      call_callback(:after_initialize)
    end

    def valid?
      return @errors.blank?
    end

    def success?
      @success == true && valid?
    end

    def fail?
      !success?
    end

    def response_status
      @response_status ||= :bad_request
    end

    def changed?
      changed_attributes.any?
    end

    def valid_user?
      user_class = NiftyServices.config.user_class

      raise 'Invalid User class. Use NitfyService.config.user_class = ClassName' if user_class.blank?

      valid_object?(@user, user_class)
    end

    def callback_fired?(callback_name)
      return (
              callback_fired_in?(@fired_callbacks, callback_name) ||
              callback_fired_in?(@custom_fired_callbacks, callback_name) ||
              callback_fired_in?(@custom_fired_callbacks, "#{callback_name}_callback")
             )
    end

    alias :callback_called? :callback_fired?

    def option_exists?(key)
      @options && @options.key?(key.to_sym)
    end

    def option_enabled?(key)
      option_exists?(key) && @options[key.to_sym] == true
    end

    def option_disabled?(key)
      !option_enabled?(key)
    end

    def register_callback(callback_name, method_name, &block)
      method_name = :"#{method_name.to_s.gsub(/\Z_callback/, '')}_callback"

      @registered_callbacks[callback_name.to_sym] << method_name
    end

    def register_callback_action(callback_name, &block)
      cb_name = :"#{callback_name.to_s.gsub(/\Z_callback/, '')}_callback"
      @callbacks_actions[cb_name] = block
    end

    def add_error(error)
      add_method = error.is_a?(Array) ? :concat : :push
      @errors.send(add_method, error)
    end

    private
    def initial_callbacks_setup
      @fired_callbacks, @custom_fired_callbacks = {}, {}
      @callbacks_actions = {}
      @registered_callbacks = Hash.new {|k,v| k[v] = [] }
    end

    def success_response(status = :ok)
      unless Configuration::SUCCESS_RESPONSE_STATUS.key?(status.to_sym)
        raise "#{status} is not a valid success response status"
      end

      with_before_and_after_callbacks(:success) do
        @success = true
        set_response_status(status)
      end
    end

    def success_created_response
      success_response(:created)
    end

    def set_response_status(status)
      @response_status = response_status_reason_for(status)
      @response_status_code = response_status_code_for(status)
    end

    def response_status_for(status)
      error_list = Configuration::ERROR_RESPONSE_STATUS
      success_list = Configuration::SUCCESS_RESPONSE_STATUS

      select_method = [Symbol, String].member?(status.class) ? :key : :value

      response_list = error_list.merge(success_list)

      selected_status = response_list.select do |status_key, status_code|
        if select_method == :key
          status_key == status
        else
          status_code == status
        end
      end
    end

    def response_status_code_for(status)
      response_status_for(status).values.first
    end

    def response_status_reason_for(status)
      response_status_for(status).keys.first
    end

    def error(status, message_key, options = {})
      with_before_and_after_callbacks(:error) do
        set_response_status(status)
        error_message = process_error_message_for_key(message_key, options)

        add_error(error_message)

        error_message
      end
    end

    def error!(status, message_key, options = {})
      error(status, message_key, options)

      # TODO:
      # maybe throw a Exception making bang(!) semantic
      # raise "NiftyServices::V1::Exceptions::#{status.titleize}".constantize
      return false
    end

    def call_callback(callback_name)
      callback_name = callback_name.to_s.underscore.to_sym

      if self.respond_to?(callback_name, true) # include private methods
        @fired_callbacks[callback_name.to_sym] = true

        invoke_callback(method(callback_name))
        call_registered_callbacks_for(callback_name)
      end

      # allow chained methods
      self
    end

    def valid_object?(record, expected_class)
      record.present? && record.is_a?(expected_class)
    end

    def filter_hash(hash, whitelist_keys = [])
      (hash || {}).symbolize_keys.slice(*whitelist_keys.map(&:to_sym))
    end

    def changes(old, current, attributes = {})
      changes = []

      return changes if old.blank? || current.blank?

      old_attributes = old.attributes.slice(*attributes.map(&:to_s))
      new_attributes = current.attributes.slice(*attributes.map(&:to_s))

      new_attributes.each do |attribute, value|
        changes << attribute if (old_attributes[attribute] != value)
      end

      changes
    end

    def i18n_namespace
      NiftyServices.configuration.i18n_namespace
    end

    def i18n_errors_namespace
      "#{i18n_namespace}.errors"
    end

    def process_error_message_for_key(message_key, options)
      if message_key.class.to_s == 'ActiveModel::Errors'
        message = message_key.messages
      elsif message_key.is_a?(Array) && message_key.first.is_a?(Hash)
        message = message_key
      else
        message = I18n.t("#{i18n_errors_namespace}.#{message_key}", options)
      end

      message
    end

    def with_before_and_after_callbacks(callback_basename, &block)
      call_callback(:"before_#{callback_basename}")

      response = yield(block) if block_given?

      call_callback(:"after_#{callback_basename}")

      response
    end

    def call_registered_callbacks_for(callback_name)
      instance_call_all_custom_registered_callbacks_for(callback_name)
      class_call_all_custom_registered_callbacks_for(callback_name)
    end

    def instance_call_all_custom_registered_callbacks_for(callback_name)
      @fired_callbacks[callback_name] = true

      callbacks = @registered_callbacks[callback_name.to_sym]

      callbacks.each do |cb|
        if callback = @callbacks_actions[cb.to_sym]
          @custom_fired_callbacks[cb.to_sym] = true
          invoke_callback(callback)
        end
      end
    end

    def class_call_all_custom_registered_callbacks_for(callback_name)
      classes_chain = self.class.ancestors.map(&:to_s).grep /\ANiftyServices/
      klasses = @@registered_callbacks.keys.map(&:to_s) & classes_chain

      klasses.each do |klass|
        class_call_all_custom_registered_callbacks_for_class(klass, callback_name)
      end
    end

    def class_call_all_custom_registered_callbacks_for_class(class_name, callback_name)
      class_callbacks = @@registered_callbacks[class_name.to_sym]
      callbacks = class_callbacks[callback_name.to_sym] || []

      callbacks.each do |cb|
        @custom_fired_callbacks[cb.to_sym] = true
        invoke_callback(method(cb))
      end
    end

    def callback_fired_in?(callback_list, callback_name)
      return callback_list[callback_name.to_sym].present?
    end

    def invoke_callback(method)
      method.call
    end

    NiftyServices::Configuration.response_errors_list.each do |reason_string, status_code|
      define_error_response_method(reason_string, status_code)
    end

    protected
    def not_implemented_exception(method_name)
      raise NotImplementedError, "#{method_name} must be implemented in subclass"
    end
  end
end