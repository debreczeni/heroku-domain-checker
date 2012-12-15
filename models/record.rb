require 'active_record'
require 'net/dns'

class Record < ActiveRecord::Base
  MAX_DOMAIN_CHARS = 67

  serialize :addresses

  def self.update_or_create_by_domain_and_position domain, position
    record = Record.find_or_initialize_by_domain domain
    record.position = position
    record.save
  end

  def self.return_existing_or_resolve_for domain
    record = Record.find_or_initialize_by_domain domain
    record.resolve_addresses if record.addresses.nil? or record.addresses.empty?
    record
  end

  def resolve_addresses
    addresses = Record.resolve_for self.domain
  end

  def self.resolve_for domain
    addresses = []

    [domain, "www.#{domain}"].each do |name_to_resolve|
      Net::DNS::Resolver.start(domain).tap do |packet|
        packet.each_cname do |cname|
          addresses << cname unless addresses.include? cname
        end
        packet.each_address do |ip|
          ip = ip.to_s
          addresses << ip unless addresses.include? ip
        end
      end
    end

    addresses
  rescue => e
    puts e.inspect, e.backtrace.join("\n")
    nil
  end
end
