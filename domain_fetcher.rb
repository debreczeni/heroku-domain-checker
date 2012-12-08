require 'nokogiri'
require 'open-uri'
require 'awesome_print'

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

class DomainFetcher
  def initialize options = {}
    @cache = Cache.new force: options[:force]
  end

  def top1000
    html = @cache.fetch 'top1000.html' do
      open('http://www.google.com/adplanner/static/top1000/').read
    end
    @cache.fetch 'domains.txt' do
      Nokogiri::HTML(html).css('#data-table tr').map do |tr|
        tr.css('td')[1].css('a')[1].content
      end
    end
  end

  def records_for domain
    `dig +short #{domain}`.split("\n")
  end

  def all_records_for domain_name, tries = 10
    records_for(domain_name) | records_for("www.#{domain_name}")
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
          new_addresses = []
        end
      end
      addresses.sort
    end
  end

  def longest_in domains
    domains.group_by(&:length).max.first
  end

  def hosted_on_heroku? record
    record.match /heroku/ or
    heroku_addresses.include?(record)
  end

  def domains_hosted_on_heroku
    domains_on_heroku = []
    top1000.each_with_index do |domain_name, index|
      records = @cache.fetch "domains/#{domain_name}" do
        all_records_for(domain_name)
      end
      on_heroku = records.any? { |r| hosted_on_heroku? r }
      domains_on_heroku << domain_name if on_heroku
      printf("%5d %#{longest_in top1000}s #{'on heroku' if on_heroku}\n",
        index + 1, domain_name)
    end
    domains_on_heroku
  end
end

fetcher = DomainFetcher.new# force: true
ap fetcher.domains_hosted_on_heroku
