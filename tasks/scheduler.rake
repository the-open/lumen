

desc "/update_news"
task :update_news => :environment do
  Mechanize.new.get("http://#{ENV['DOMAIN']}/update_news?token=#{Account.find_by(role: 'admin').generate_secret_token}")
end

namespace :digests do
  desc "/send_digests/daily"
  task :daily => :environment do
    Mechanize.new.get("http://#{ENV['DOMAIN']}/send_digests/daily?token=#{Account.find_by(role: 'admin').generate_secret_token}")
  end

  desc "/send_digests/weekly"
  task :weekly => :environment do
    Mechanize.new.get("http://#{ENV['DOMAIN']}/send_digests/weekly?#{Account.find_by(role: 'admin').generate_secret_token}")
  end
end