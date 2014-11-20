# Load the Rails application.
require File.expand_path('../application', __FILE__)

# Initialize the Rails application.
Rails.application.initialize!

#configure the CA authority
ENV['SSL_CERT_FILE'] = '/etc/ssl/certs/GeoTrust_Global_CA.pem'
