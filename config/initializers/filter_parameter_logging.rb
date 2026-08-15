# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # The OAuth authorization code rides the callback URL/body (story 0015).
  # Codes are single-use, but one logged from a FAILED exchange is unspent —
  # and log access should not equal a sign-in (security review F2).
  :code
]
