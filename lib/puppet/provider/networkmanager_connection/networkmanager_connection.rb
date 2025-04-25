# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'

# Implementation for the networkmanager_connection type using the Resource API.
class Puppet::Provider::NetworkmanagerConnection::NetworkmanagerConnection < Puppet::ResourceApi::SimpleProvider
  def get(context, name)
    result = []

    Puppet::Util::Log.new(:level => :debug, :message => "context: #{context}")
    Puppet::Util::Log.new(:level => :debug, :message => "name: #{name}")

    if name.empty?
      list_connections.each do |connection|
        data = nmcli('-t', 'connection', 'show', connection).split("\n").map(&:strip)
        # Convert the data to a hash with key-value pairs and convert empty values to nil
        data = data.map { |item| item.split(':', 2).map { |v| v.strip.empty? ? nil : v.strip } }.to_h

        Puppet::Util::Log.new(:level => :debug, :message => "data: #{data}")

        ipv4_addresses = if data['ipv4.addresses']
                           [data['ipv4.addresses']]
                         else
                           data.select { |key, _| key.start_with?('IP4.ADDRESS[') }.values
                         end
        ipv4_addresses = nil if ipv4_addresses.empty?

        ipv6_addresses = if data['ipv6.addresses']
                           [data['ipv6.addresses']]
                         else
                           data.select { |key, _| key.start_with?('IP6.ADDRESS[') }.values
                         end
        ipv6_addresses = nil if ipv6_addresses.empty?

        general_state = if data['GENERAL.STATE']
                          data['GENERAL.STATE'].downcase
                        else
                          data['GENERAL.STATE'] || 'unknown'
                        end

        result << {
          ensure: 'present',
          name: connection,
          type: data['connection.type'],
          device: data['connection.interface-name'],
          ipv4_method: data['ipv4.method'],
          ipv4_addresses: ipv4_addresses,
          ipv6_method: data['ipv6.method'],
          ipv6_addresses: ipv6_addresses,
          general_state: general_state,
          uuid: data['connection.uuid'],
          }
      end
    end

    unless name.empty?
      result << { ensure: 'present', name: name }
      # result << nmcli('-t', '-f', 'all', 'connection', 'show', name).split("\n").map(&:strip)
    end

    result
  rescue Puppet::ExecutionFailure => e
    context.err("Error listing NetworkManager connections: #{e}")
    []
  end

  private

  def list_connections
    nmcli('-t', '-f', 'name', 'connection', 'show').split("\n").map(&:strip)
  end

  def nmcli(*args)
    Puppet::Util::Execution.execute(['/usr/bin/nmcli'] + args.flatten)
  end
end
