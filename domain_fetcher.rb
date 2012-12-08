require 'nokogiri'
require 'open-uri'
require 'awesome_print'

class Cache
  def initialize options = {}
    @tmp_dir = 'tmp'
    @force = options[:force]
  end

  def fetch key, options = {}
    force = options[:force].nil? ? @force : options[:force]
    Dir.mkdir @tmp_dir unless File.directory? @tmp_dir
    filepath = File.join @tmp_dir, key
    File.delete(filepath) if force && File.exists?(filepath)
    unless File.exists? filepath
      File.open filepath, 'w' do |file|
        file.write Marshal.dump(yield)
      end
    end
    Marshal.load File.open(filepath).read
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
    @cache.fetch 'domains_hosted_on_heroku' do
      domains_on_heroku = []
      top1000.each_with_index do |domain_name, index|
        records = all_records_for(domain_name)
        is_on_heroku = ''
        records.each do |record|
          if hosted_on_heroku? record
            is_on_heroku = 'on_heroku'
            domains_hosted_on_heroku << domain_name
          end
        end
        puts sprintf("%5d %#{longest_in(top1000)}s #{is_on_heroku}", index + 1, domain_name)
      end
      domains_on_heroku
    end
  end
end

fetcher = DomainFetcher.new# force: true
ap fetcher.domains_hosted_on_heroku
# ap fetcher.heroku_addresses