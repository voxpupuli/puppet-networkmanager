# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'

# Implementation for the networkmanager_connection type using the Resource API.
# This provider interacts with NetworkManager via the `nmcli` command-line tool.
# It supports fetching, creating, updating, and deleting NetworkManager connections.
#
class Puppet::Provider::NetworkmanagerConnection::NetworkmanagerConnection < Puppet::ResourceApi::SimpleProvider
  # The `get` method retrieves the current state of NetworkManager connections.
  # It is called by Puppet to determine the "is" state of resources.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for logging and debugging.
  # @param name [String] The name of the connection to fetch. If empty, fetches all connections.
  # @return [Array<Hash>] An array of hashes representing the current state of connections.
  #
  def get(context, name)
    context.debug("Fetching NetworkManager connections for name: #{name.inspect}")

    # Fetch all connections if no specific name is provided, otherwise fetch the specific connection.
    connections = if name.empty?
                    list_connections.map { |connection| fetch_connection_data(connection) }
                  else
                    [fetch_connection_data(name)]
                  end

    # Remove any nil entries (e.g., if a connection fetch failed).
    connections.compact
  rescue Puppet::ExecutionFailure => e
    # Log an error if the `nmcli` command fails.
    context.err("Error listing NetworkManager connections: #{e}")
    []
  end

  private

  # Lists all available NetworkManager connections by name.
  # This method executes the `nmcli connection show` command.
  #
  # @return [Array<String>] An array of connection names.
  #
  # Example:
  # Real-world command: `nmcli -t -f name connection show`
  # Output:
  #   ["Wired connection 1", "Home WiFi", "VPN Connection"]
  #
  def list_connections
    nmcli('-t', '-f', 'name', 'connection', 'show').split("\n").map(&:strip)
  end

  # Fetches detailed information about a specific NetworkManager connection.
  # This method executes the `nmcli connection show <connection>` command.
  #
  # @param connection [String] The name of the connection to fetch.
  # @return [Hash] A hash representing the connection's properties.
  #
  # Example:
  # Real-world command: `nmcli -t connection show "Home WiFi"`
  # Output:
  #   GENERAL.STATE:activated
  #   connection.type:wifi
  #   connection.interface-name:wlan0
  #   ipv4.method:auto
  #   IP4.ADDRESS[1]:192.168.1.100/24
  #   IP4.DNS[1]:8.8.8.8
  #   connection.uuid:123e4567-e89b-12d3-a456-426614174000
  #
  def fetch_connection_data(connection)
    # Execute the `nmcli` command to fetch connection details.
    data = nmcli('-t', 'connection', 'show', connection).split("\n").map(&:strip)

    # Convert the output into a hash of key-value pairs.
    # Empty values are converted to `nil`.
    data = data.map { |item| item.split(':', 2).map { |v| v.strip.empty? ? nil : v.strip } }.to_h

    # Return a structured hash representing the connection's properties.
    {
      ensure: 'present',
      name: connection,
      type: data['connection.type'],
      device: data['connection.interface-name'],
      ipv4_method: data['ipv4.method'],
      ipv4_addresses: extract_addresses(data, 'IP4.ADDRESS'),
      ipv4_dns: extract_addresses(data, 'IP4.DNS'),
      ipv6_method: data['ipv6.method'],
      ipv6_addresses: extract_addresses(data, 'IP6.ADDRESS'),
      ipv6_dns: extract_addresses(data, 'IP6.DNS'),
      general_state: (data['GENERAL.STATE'] || 'unknown').downcase,
      uuid: data['connection.uuid'],
    }
  rescue Puppet::ExecutionFailure
    # Return `nil` if the `nmcli` command fails for this connection.
    nil
  end

  # Extracts multiple values (e.g., IP addresses or DNS servers) from the `nmcli` output.
  # This method handles fields like `IP4.ADDRESS[1]`, `IP4.ADDRESS[2]`, etc.
  #
  # @param data [Hash] The hash of connection properties.
  # @param prefix [String] The prefix to filter keys (e.g., "IP4.ADDRESS").
  # @return [Array<String>, nil] An array of values, or `nil` if no values are found.
  #
  # Example:
  # Input:
  #   data = {
  #     "IP4.ADDRESS[1]" => "192.168.1.100/24",
  #     "IP4.ADDRESS[2]" => "192.168.1.101/24"
  #   }
  #   prefix = "IP4.ADDRESS"
  # Output:
  #   ["192.168.1.100/24", "192.168.1.101/24"]
  #
  def extract_addresses(data, prefix)
    addresses = data.select { |key, _| key.start_with?(prefix) }.values
    addresses.empty? ? nil : addresses
  end

  # Executes the `nmcli` command with the specified arguments.
  # This method uses Puppet's `Puppet::Util::Execution.execute` to run the command.
  #
  # @param args [Array<String>] The arguments to pass to `nmcli`.
  # @return [String] The output of the command.
  #
  def nmcli(*args)
    Puppet::Util::Execution.execute(['/usr/bin/nmcli'] + args)
  end
end
