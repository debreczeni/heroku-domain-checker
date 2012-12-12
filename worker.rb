#!/usr/bin/env ruby

# require 'debugger'

$:.unshift File.dirname(__FILE__)
require 'boot'
require 'lib/cache'
require 'lib/hosting_checker'
require 'models/record'

Boot.boot!
# Boot.clean_db!

if ARGV[0] == 'start'
  checker = HostingChecker.new# force: true
  checker.flag_domains_hosted_on_heroku
end
