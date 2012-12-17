#!/usr/bin/env ruby

# require 'debugger'

$:.unshift File.dirname(__FILE__)
require 'boot'
require 'lib/cache'
require 'lib/hosting_checker'
require 'models/record'
require 'models/heroku_address'
require 'sinatra'

Boot.boot!
# Boot.clean_db!

get '/' do
  'Hello world!'
end

checker = HostingChecker.new# force: true

case ARGV[0]
when 'flag'
  checker.flag_domains_hosted_on_heroku
when 'save'
  checker.save_top1m_site_in_database
end
