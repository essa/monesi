
require 'webmock/rspec'
require 'pry'

require 'monesi/command_parser'
require 'monesi/feed_manager'

$WEBMOCK_TEST = true
RSpec.configure do |config|
  if ENV['PASSTHROUGH_TEST']
    puts "disabling WebMock..."
    WebMock.disable!
    $WEBMOCK_TEST = false
  end
end
