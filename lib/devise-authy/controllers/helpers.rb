module DeviseAuthy
  module Controllers
    module Helpers
      extend ActiveSupport::Concern

      included do
        before_filter :check_request_and_redirect_to_verify_token, :if => :is_signing_in?
      end

      private
      def remember_device
        cookies.signed[:remember_device] = {
          :value => Time.now.to_i,
          :secure => !(Rails.env.test? || Rails.env.development?)
        }
      end

      def require_token?
        if cookies.signed[:remember_device].present? &&
          (Time.now.to_i - cookies.signed[:remember_device].to_i) < \
          resource_class.authy_remember_device.to_i
          return false
        end

        return true
      end

      def is_signing_in?
        if devise_controller? && signed_in?(resource_name) &&
           self.class == Devise::SessionsController || self.class.ancestors.include?(Devise::SessionsController) && 
           self.action_name == "create"
          return true
        end

        return false
      end

      def check_request_and_redirect_to_verify_token
        if signed_in?(resource_name) &&
           warden.session(resource_name)[:with_authy_authentication] &&
           require_token?
          # login with 2fa
          id = warden.session(resource_name)[:id]
          warden.logout
          warden.reset_session! # make sure the session resetted
          session["#{resource_name}_id"] = id
          # this is safe to put in the session because the cookie is signed
          session["#{resource_name}_password_checked"] = true
          session["#{resource_name}_return_to"] = request.path if request.get?

          redirect_to verify_authy_path_for(resource_name)
          return
        end
      end

      def verify_authy_path_for(resource_or_scope = nil)
        scope = Devise::Mapping.find_scope!(resource_or_scope)
        send("#{scope}_verify_authy_path")
      end
    end
  end
end

