#!/usr/bin/env ruby

require 'open-uri'
require 'csv'
require 'uri'
require 'digest/sha1'
require 'net/dns'

class Cache
  def initialize options = {}
    @tmp_dir = 'cache'
    @force = options[:force]
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

  def records_for domain
    addresses = []

    packet = Net::DNS::Resolver.start(domain)
    packet.each_cname { |cname| addresses << cname; }
    packet.each_address  { |ip| addresses << ip.to_s }

    packet = Net::DNS::Resolver.start("www.#{domain}")
    packet.each_cname { |cname| addresses << cname }
    packet.each_address  { |ip| addresses << ip.to_s }

    addresses.uniq
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

  def domains_hosted_on_heroku
    longest_domain_length = longest_in top_sites
    domains_on_heroku = []
    top_sites.each_with_index do |domain_name, index|
      begin
        records = @cache.fetch "domains/#{domain_name}" do
          records_for(domain_name)
        end
      rescue ArgumentError
        records = @cache.fetch "domains/#{domain_name}", force: true do
          records_for(domain_name)
        end
      end
      on_heroku = records.any? { |r| hosted_on_heroku? r }
      domains_on_heroku << domain_name if on_heroku
      printf("%5d %#{longest_domain_length}s #{'on heroku' if on_heroku}\n",
        index + 1, domain_name)
    end
    domains_on_heroku
  end
end

checker = HostingChecker.new# force: true
p checker.domains_hosted_on_heroku
# p checker.top_sites.group_by(&:length).max
