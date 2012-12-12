#!/usr/bin/env ruby

require 'open-uri'
require 'csv'
require 'uri'
require 'digest/sha1'
require 'net/dns'
require 'active_record'
# require 'debugger'

$:.unshift File.dirname(__FILE__)
require 'boot'
require 'lib/cache'
require 'models/record'

class HostingChecker
  def initialize options = {}
    @cache = Cache.new force: options[:force]
  end

  def ranking_of a_site
    CSV.read('data/top-1m.csv').each { |the_site|
      return the_site.first if the_site.last == a_site
    }
  end

  def top_sites
    @cache.fetch 'top_sites' do
      CSV.read('data/top-1m.csv').map { |site|
        site.last.match(URI::PATTERN::HOSTNAME).to_s
      }.uniq.delete_if(&:empty?)
    end
  end

  def heroku_addresses
    @cache.fetch 'heroku_addresses' do
      addresses = []
      %w{proxy.herokuapp.com proxy.heroku.com}.each do |heroku_domain|
        puts "digging #{heroku_domain}"
        (1..1000).each do |index|
          printf("%3d ", index)
          addresses_dug = records_for(heroku_domain)
          new_addresses = addresses_dug - addresses
          puts new_addresses.empty? ? '' : new_addresses.join(' ')
          addresses = addresses + new_addresses
        end
      end
      addresses.sort
    end
  end

  def longest_in domains
    @cache.fetch "longest_in/#{Digest::SHA1.hexdigest domains.join}" do
      domains.group_by(&:length).max.first
    end
  end

  def hosted_on_heroku? record
    record.match /heroku/ or
    heroku_addresses.include?(record)
  end

  def flag_domains_hosted_on_heroku
    longest_domain_length = longest_in top_sites
    top_sites.each_with_index do |domain_name, index|
      record = Record.find_or_initialize_then_resolve_by domain_name
      record.on_heroku = record.addresses.any? { |r| hosted_on_heroku? r }
      record.save!

      printf("%5d %#{longest_domain_length}s #{'on heroku' if record.on_heroku}\n",
        index + 1, domain_name)
    end
  end
end

Boot.boot!
# Boot.clean_db!

if ARGV[0] == 'start'
  checker = HostingChecker.new# force: true
  checker.flag_domains_hosted_on_heroku
end
