Bugsnag.configure do |config|
  config.api_key = Config['BUGSNAG_API_KEY']
  config.project_root = Padrino.root
end
