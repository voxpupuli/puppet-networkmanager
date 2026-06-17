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
    requested_names = case name
                      when nil
                        []
                      when Array
                        name
                      else
                        [name]
                      end

    requested_names = requested_names.flatten.compact.map(&:to_s).reject(&:empty?)
    context.debug("Fetching NetworkManager connections for names: #{requested_names.inspect}")

    # Fetch all connections if no specific names are provided, otherwise fetch each requested connection.
    connections = if requested_names.empty?
                    list_connections.map { |connection| fetch_connection_data(context, connection) }
                  else
                    requested_names.map { |connection| fetch_connection_data(context, connection) }
                  end

    # Remove any nil entries (e.g., if a connection fetch failed).
    connections.compact
  rescue Puppet::ExecutionFailure => e
    # Log an error if the `nmcli` command fails.
    context.err("Error listing NetworkManager connections: #{e}")
    []
  end

  def set(context, changes)
    changes.each do |name, change|
      is = change[:is] || {}
      should = change[:should] || {}

      if should[:ensure] == 'absent'
        context.notice("Deleting '#{name}'")
        delete_connection(name)
      elsif is.empty? || is[:ensure] == 'absent'
        context.notice("Creating '#{name}'")
        create_connection(context, name, should)
      else
        context.notice("Updating '#{name}'")
        update_connection(context, name, should)
      end
    end
  rescue Puppet::ExecutionFailure => e
    context.err("Failed to apply networkmanager_connection changes: #{e}")
    raise
  end

  private

  PROPERTY_MAP = {
    device: 'connection.interface-name',
    ipv4_method: 'ipv4.method',
    ipv4_addresses: 'ipv4.addresses',
    ipv4_dns: 'ipv4.dns',
    ipv4_gateway: 'ipv4.gateway',
    ipv6_method: 'ipv6.method',
    ipv6_addresses: 'ipv6.addresses',
    ipv6_dns: 'ipv6.dns',
    ipv6_gateway: 'ipv6.gateway',
  }.freeze unless const_defined?(:PROPERTY_MAP, false)

  def create_connection(context, name, resource)
    args = ['connection', 'add', 'con-name', name, 'type', resource.fetch(:type)]
    args += ['ifname', resource[:device]] if resource[:device]
    nmcli(*args)
    apply_connection_settings(context, name, resource)
  end

  def update_connection(context, name, resource)
    apply_connection_settings(context, name, resource)
  end

  def delete_connection(name)
    nmcli('connection', 'delete', name)
  end

  def apply_connection_settings(context, name, resource)
    modifications = []

    PROPERTY_MAP.each do |key, nmcli_key|
      next unless resource.key?(key)

      value = normalize_setting_value(resource[key])
      modifications += [nmcli_key, value]
    end

    return if modifications.empty?

    nmcli('connection', 'modify', name, *modifications)
    maybe_reapply_connection(context, name, resource)
  end

  def maybe_reapply_connection(context, name, resource)
    return unless resource[:reapply]

    device = resolve_reapply_device(name, resource)
    return if device.nil? || device.empty?

    nmcli('device', 'reapply', device)
  rescue Puppet::ExecutionFailure => e
    context.debug("Failed to reapply device '#{device}' for connection '#{name}': #{e}") if context
  end

  def resolve_reapply_device(name, resource)
    return resource[:device] if resource[:device] && !resource[:device].empty?

    output = nmcli('-t', '-f', 'connection.interface-name', 'connection', 'show', name).to_s.strip
    return nil if output.empty?

    output.split(':', 2).last.to_s.strip
  end

  def normalize_setting_value(value)
    return '' if value.nil?

    value.is_a?(Array) ? value.join(',') : value.to_s
  end

  # Splits a comma-separated profile value (e.g. "8.8.8.8,1.1.1.1") into an Array.
  # Returns nil when the value is absent or empty.
  def split_profile_list(value)
    return nil if value.nil? || value.strip.empty?

    result = value.split(',').map(&:strip).reject(&:empty?)
    result.empty? ? nil : result
  end

  def normalize_general_state(value)
    return 'unknown' if value.nil? || value.strip.empty?

    normalized = value.downcase.strip
    normalized = normalized[/\(([^)]+)\)/, 1] || normalized

    case normalized
    when 'activated', 'unknown', 'down', 'connecting', 'connected', 'disconnecting'
      normalized
    when 'activating', 'deactivating'
      'connecting'
    else
      'unknown'
    end
  end

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
    nmcli('-t', '-f', 'name', 'connection', 'show').split("\n").map(&:strip).reject(&:empty?)
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
  #
  def fetch_connection_data(context, connection)
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
      ipv4_addresses: split_profile_list(data['ipv4.addresses']),
      ipv4_dns: split_profile_list(data['ipv4.dns']),
      ipv4_gateway: data['ipv4.gateway'],
      ipv6_method: data['ipv6.method'],
      ipv6_addresses: split_profile_list(data['ipv6.addresses']),
      ipv6_dns: split_profile_list(data['ipv6.dns']),
      ipv6_gateway: data['ipv6.gateway'],
      general_state: normalize_general_state(data['GENERAL.STATE']),
    }
  rescue Puppet::ExecutionFailure => e
    context.err("Error fetching NetworkManager connection '#{connection}': #{e}") if context

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
    addresses = data
                .select { |key, _| key.start_with?(prefix) }
                .sort_by { |key, _| key[/\[(\d+)\]\z/, 1].to_i }
                .map { |_, value| value }
    addresses.empty? ? nil : addresses
  end

  # Executes the `nmcli` command with the specified arguments.
  # This method uses Puppet's `Puppet::Util::Execution.execute` to run the command.
  #
  # @param args [Array<String>] The arguments to pass to `nmcli`.
  # @return [String] The output of the command.
  #
  def nmcli(*args)
    command = Puppet::Util.which('nmcli')
    raise Puppet::Error, 'Unable to find nmcli in PATH' unless command

    Puppet::Util::Execution.execute([command] + args)
  end
end
