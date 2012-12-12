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
  rescue => e
    puts e.inspect
    puts e.backtrace.join "\n"
    nil
  end
end
