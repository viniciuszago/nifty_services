module NiftyServices
  class BaseDeleteService < BaseCrudService
    def execute
      execute_action do
        with_before_and_after_callbacks(:delete) do
          if can_execute_action?
            errors = @record.errors
            destroy_record ? success_response : bad_request_error(errors)
          end
        end
      end
    end

    private

    def destroy_record
      @record.try(:destroy) || @record.try(:delete)
    end

    def can_execute?
      unless valid_record?
        return not_found_error!("#{record_error_key}.not_found")
      end

      if validate_user? && !valid_user?
        return not_found_error!(invalid_user_error_key)
      end

      true
    end

    def can_delete_record?
      unless user_can_delete_record?
        return (valid? ? forbidden_error!(user_can_delete_error_key) : false)
      end

      true
    end

    def can_execute_action?
      can_delete_record?
    end

    def user_can_delete_record?
      unless @record.respond_to?(:user_can_delete?)
        return not_implemented_exception(__method__)
      end

      @record.user_can_delete?(@user)
    end

    def user_cant_delete_error_key
      "#{record_error_key}.user_cant_delete"
    end
  end
end
