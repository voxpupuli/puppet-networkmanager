# frozen_string_literal: true

require 'puppet/resource_api/simple_provider'
require 'ipaddr'

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
    existing_connections = list_connections
    connections = if requested_names.empty?
                    existing_connections.map { |connection| fetch_connection_data(context, connection) }
                  else
                    requested_names
                      .select { |connection| existing_connections.include?(connection) }
                      .map { |connection| fetch_connection_data(context, connection) }
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

      if should[:ensure].to_s == 'absent'
        context.notice("Deleting '#{name}'")
        delete_connection(name)
      elsif is.empty? || is[:ensure].to_s == 'absent'
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

  unless const_defined?(:PROPERTY_MAP, false)
    PROPERTY_MAP = {
      device: 'connection.interface-name',
      ipv4_method: 'ipv4.method',
      ipv4_addresses: 'ipv4.addresses',
      ipv4_dns: 'ipv4.dns',
      ipv4_gateway: 'ipv4.gateway',
      ipv4_routes: 'ipv4.routes',
      ipv6_method: 'ipv6.method',
      ipv6_addresses: 'ipv6.addresses',
      ipv6_dns: 'ipv6.dns',
      ipv6_gateway: 'ipv6.gateway',
      ipv6_routes: 'ipv6.routes',
    }.freeze
  end

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
    validate_routes!(name, resource)
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

  def validate_routes!(name, resource)
    validate_ip_routes!(name, resource, 4)
    validate_ip_routes!(name, resource, 6)
  end

  def validate_ip_routes!(name, resource, family)
    routes = resource[:"ipv#{family}_routes"] || []
    return if routes.empty?

    gateway = resource[:"ipv#{family}_gateway"]
    default_destination = ((family == 4) ? '0.0.0.0/0' : '::/0')

    raise Puppet::Error, "Connection '#{name}' declares both ipv#{family}_gateway and a default route in ipv#{family}_routes" if gateway && routes.any? { |route| same_network?(route_value(route, :destination), default_destination) }

    connected_networks = Array(resource[:"ipv#{family}_addresses"]).map { |address| canonical_network(address) }
    duplicate = routes.find do |route|
      connected_networks.include?(canonical_network(route_value(route, :destination)))
    end
    return unless duplicate

    destination = route_value(duplicate, :destination)
    raise Puppet::Error, "Connection '#{name}' declares connected network '#{destination}' in ipv#{family}_routes; it is created automatically from ipv#{family}_addresses"
  end

  def route_value(route, key)
    route[key] || route[key.to_s]
  end

  def same_network?(left, right)
    canonical_network(left) == canonical_network(right)
  end

  def canonical_network(value)
    network = IPAddr.new(value)
    [network.to_s, network.prefix]
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

    return value.map { |entry| format_route_entry(entry) }.compact.join(',') if value.is_a?(Array) && value.first.is_a?(Hash)

    value.is_a?(Array) ? value.join(',') : value.to_s
  end

  def format_route_entry(entry)
    destination = entry[:destination] || entry['destination']
    return nil if destination.nil? || destination.to_s.strip.empty?

    next_hop = entry[:next_hop] || entry['next_hop']
    metric = entry[:metric] || entry['metric']

    parts = [destination.to_s.strip]
    parts << next_hop.to_s.strip if next_hop && !next_hop.to_s.strip.empty?
    parts << metric.to_s.strip if metric && !metric.to_s.strip.empty?
    parts.join(' ')
  end

  # Splits a comma-separated profile value (e.g. "8.8.8.8,1.1.1.1") into an Array.
  # Returns nil when the value is absent or empty.
  def split_profile_list(value)
    return nil if value.nil? || value.strip.empty?

    result = value.split(',').map(&:strip).reject(&:empty?)
    result.empty? ? nil : result
  end

  def parse_routes(value)
    return [] if value.nil? || value.strip.empty?

    value.split(',').map(&:strip).reject(&:empty?).map { |route| parse_route_entry(route) }.compact
  end

  def parse_route_entry(route)
    parts = route.split(%r{\s+})
    return nil if parts.empty?

    parsed = { 'destination' => parts[0] }
    parsed['next_hop'] = parts[1] if parts[1] && !parts[1].empty?
    parsed['metric'] = Integer(parts[2], 10) if parts[2] && !parts[2].empty?
    parsed
  rescue ArgumentError
    parsed
  end

  def normalize_general_state(value)
    return 'unknown' if value.nil? || value.strip.empty?

    normalized = value.downcase.strip
    normalized = normalized[%r{\(([^)]+)\)}, 1] || normalized

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
      ipv4_routes: parse_routes(data['ipv4.routes']),
      ipv6_method: data['ipv6.method'],
      ipv6_addresses: split_profile_list(data['ipv6.addresses']),
      ipv6_dns: split_profile_list(data['ipv6.dns']),
      ipv6_gateway: data['ipv6.gateway'],
      ipv6_routes: parse_routes(data['ipv6.routes']),
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
                .sort_by { |key, _| key[%r{\[(\d+)\]\z}, 1].to_i }
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
