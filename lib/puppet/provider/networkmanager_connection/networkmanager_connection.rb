# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'

# Implementation for the networkmanager_connection type using the Resource API.
class Puppet::Provider::NetworkmanagerConnection::NetworkmanagerConnection < Puppet::ResourceApi::SimpleProvider
  def get(context, name)
    context.debug("Fetching NetworkManager connections for name: #{name.inspect}")

    connections = if name.empty?
                    list_connections.map { |connection| fetch_connection_data(connection) }
                  else
                    [fetch_connection_data(name)]
                  end

    connections.compact
  rescue Puppet::ExecutionFailure => e
    context.err("Error listing NetworkManager connections: #{e}")
    []
  end

  private

  def list_connections
    nmcli('-t', '-f', 'name', 'connection', 'show').split("\n").map(&:strip)
  end

  def fetch_connection_data(connection)
    data = nmcli('-t', 'connection', 'show', connection).split("\n").map(&:strip)
    data = data.map { |item| item.split(':', 2).map { |v| v.strip.empty? ? nil : v.strip } }.to_h

    {
      ensure: 'present',
      name: connection,
      type: data['connection.type'],
      device: data['connection.interface-name'],
      ipv4_method: data['ipv4.method'],
      ipv4_addresses: extract_addresses(data, 'IP4.ADDRESS'),
      ipv6_method: data['ipv6.method'],
      ipv6_addresses: extract_addresses(data, 'IP6.ADDRESS'),
      general_state: (data['GENERAL.STATE'] || 'unknown').downcase,
      uuid: data['connection.uuid'],
    }
  rescue Puppet::ExecutionFailure
    nil
  end

  def extract_addresses(data, prefix)
    addresses = data.select { |key, _| key.start_with?(prefix) }.values
    addresses.empty? ? nil : addresses
  end

  def nmcli(*args)
    Puppet::Util::Execution.execute(['/usr/bin/nmcli'] + args)
  end
end
