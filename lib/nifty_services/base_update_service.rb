module NiftyServices
  class BaseUpdateService < BaseCrudService
    def execute
      execute_action do
        with_before_and_after_callbacks(:update) do
          if can_execute_action?
            duplicate_records_before_update

            @record = update_record

            if success_updated?
              success_response
            else
              errors = update_errors
              bad_request_error(errors) unless errors.empty?
            end
          end
        end
      end
    end

    def changed_attributes
      return [] if fail?
      @changed_attributes ||= changes(@last_record,
                                      @record,
                                      changed_attributes_array)
    end

    private

    def changed_attributes_array
      record_allowed_attributes.keys
    end

    def success_updated?
      @record.valid?
    end

    def update_errors
      @record.errors
    end

    def update_record
      @record.class.send(:update, @record.id, record_allowed_attributes)
    end

    def can_execute?
      return not_found_error!(invalid_record_error_key) unless valid_record?

      if validate_user? && !valid_user?
        return not_found_error!(invalid_user_error_key)
      end

      true
    end

    def can_update_record?
      unless user_can_update_record?
        return (valid? ? forbidden_error!(user_cant_update_error_key) : false)
      end

      true
    end

    def can_execute_action?
      can_update_record?
    end

    def user_can_update_record?
      unless @record.respond_to?(:user_can_update?)
        return not_implemented_exception(__method__)
      end

      @record.user_can_update?(@user)
    end

    def duplicate_records_before_update
      @last_record = @record.dup
    end

    def invalid_record_error_key
      "#{record_error_key}.not_found"
    end

    def user_cant_update_error_key
      "#{record_error_key}.user_cant_update"
    end
  end
end
