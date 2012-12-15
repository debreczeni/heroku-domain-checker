require 'open-uri'
require 'csv'
require 'uri'
require 'digest/sha1'

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

  def top_sites_with_positions
    @cache.fetch 'top_sites_with_positions' do
      CSV.read('data/top-1m.csv').map do |position_and_address|
        position, address = position_and_address
        return nil unless address
        if domain = address.match(URI::PATTERN::HOSTNAME)
          [position, domain.to_s]
        else nil end
      end.compact.uniq
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
    Record.where(status: :unchecked).find_in_batches do |records|
      Record.where(id: records.map(&:id)).update_all(:status, :checking)
      records.each do |record|
        begin
          printf("%5d %#{Record::MAX_DOMAIN_CHARS}s #{'on heroku' if record.on_heroku}\n",
            index + 1, domain_name)
          record.resolve_addresses
          record.on_heroku = record.addresses.any? { |r| hosted_on_heroku? r }
          record.save!
        rescue => e
          puts e.inspect, e.backtrace.join("\n")
        end
      end
      Record.where(id: records.map(&:id)).update_all(:status, :checked)
    end
  end

  def save_top1m_site_in_database
    top_sites_with_positions.each do |position_and_domain|
      begin
        position, domain = position_and_domain
        position = position.to_i
        next if position < ENV['START'].to_i
        printf("%5d %#{Record::MAX_DOMAIN_CHARS}s ...", position, domain)
        # Record.update_or_create_by_domain_and_position domain, position
        Record.create position: position, domain: domain
        printf("Done\n")
      rescue => e
        puts e.inspect, e.backtrace.join("\n")
      end
    end
  end

end
