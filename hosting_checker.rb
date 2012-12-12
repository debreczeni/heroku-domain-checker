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

class Cache
  def initialize options = {}
    @tmp_dir = 'cache'
    @force = options[:force]
  end

  def get key
    file_name = File.join @tmp_dir, key
    if File.exists? file_name
      begin
        Marshal.load File.open(file_name).read
      rescue => e
        puts e.inspect
        puts e.backtrace.join "\n"
        nil
      end
    else
      nil
    end
  end

  def fetch key, options = {}
    force = options[:force].nil? ? @force : options[:force]
    file_name = File.join @tmp_dir, key
    file_dir = File.dirname file_name
    Dir.mkdir file_dir unless File.directory? file_dir
    File.delete(file_name) if force && File.exists?(file_name)
    unless File.exists? file_name
      File.open file_name, 'w' do |file|
        file.write Marshal.dump(yield)
      end
    end
    Marshal.load File.open(file_name).read
  end
end

class Record < ActiveRecord::Base
  serialize :addresses

  def self.find_or_initialize_then_resolve_by domain
    record = Record.find_or_initialize_by_domain domain
    return record unless record.addresses.nil? or record.addresses.empty?

    record.addresses = Record.resolve_for domain

    record
  end

  def self.resolve_for domain
    addresses = []

    packet = Net::DNS::Resolver.start(domain)
    packet.each_cname { |cname| addresses << cname; }
    packet.each_address  { |ip| addresses << ip.to_s }

    packet = Net::DNS::Resolver.start("www.#{domain}")
    packet.each_cname { |cname| addresses << cname }
    packet.each_address  { |ip| addresses << ip.to_s }

    addresses.uniq
  rescue Net::DNS::Resolver::NoResponseError => e
    puts e.inspect
    puts e.backtrace.join "\n"
    ['nameserver.notfound']
  end
end

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

checker = HostingChecker.new# force: true
checker.flag_domains_hosted_on_heroku
# p checker.top_sites.group_by(&:length).max
