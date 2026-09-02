# Default cookie_store ships with no Max-Age. WKWebView (ios/Tondo shell) reads
# that as a process-scoped session cookie and drops it when the app is
# terminated (swipe-kill), unlike Safari — so a signed-in reader loses
# session[:user_id] on next launch even though the device cookie (`.permanent`,
# device_registrations_controller.rb) survives fine. expire_after gives the
# cookie a real Max-Age so WKWebView persists it like any other cookie.
Rails.application.config.session_store :cookie_store, key: "_tondo_session", expire_after: 1.year
