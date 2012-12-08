require 'nokogiri'
require 'open-uri'
require 'awesome_print'

class Cache
  def initialize options = {}
    @tmp_dir = 'tmp'
    @force = !options[:force].nil?
  end

  def fetch key, options = {}
    force = options[:force].nil? ? @force : options[:force]
    Dir.mkdir @tmp_dir unless File.directory? @tmp_dir
    filepath = File.join @tmp_dir, key
    if File.exists? filepath
      File.delete(filepath) if force
    else
      File.open filepath, 'w' do |file|
        file.write Marshal.dump(yield)
      end
    end
    Marshal.load File.open(filepath).read
  end
end

class DomainFetcher
  def initialize options = {}
    @cache = Cache.new force: !options[:force].nil?
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

  def addresses_for domain
    `dig +short #{domain}`.split("\n")
  end

  def heroku_addresses
    @cache.fetch 'heroku_addresses' do
      addresses = []
      (1..200).each do |index|
        %w{proxy.herokuapp.com proxy.heroku.com}.each do |heroku_domain|
          addresses = addresses + addresses_for(heroku_domain)
        end
      end
      addresses.sort.uniq
    end
  end

  def self.parse_top1000 options = {}
    heroku_domains = []
    self.new(options||{}).top1000[0..1].each_with_index do |domain_name, index|
      records = `dig +short #{domain_name}`#.split("\n")
      heroku = ''
      if records.match(/heroku/)
        heroku = 'yaay'
        heroku_domains << domain_name
      end
      puts sprintf("%5d %30s #{heroku}", index + 1, domain_name)
    end
    puts 'heroku domains:'
    ap heroku_domains
    nil
  end
end

# DomainFetcher.parse_top1000 #force: true
fetcher = DomainFetcher.new
ap fetcher.heroku_addresses