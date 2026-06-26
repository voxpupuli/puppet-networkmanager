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

  # Applies Puppet Resource API changes to NetworkManager profiles.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for logging.
  # @param changes [Hash] Resource changes keyed by connection name.
  # @return [void]
  #
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

  # Creates a persistent NetworkManager profile and applies its settings.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for logging.
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [void]
  #
  def create_connection(context, name, resource)
    args = ['connection', 'add', 'con-name', name, 'type', resource.fetch(:type)]
    args += ['ifname', resource[:device]] if resource[:device]
    nmcli(*args)
    apply_connection_settings(context, name, resource)
  end

  # Updates settings on an existing NetworkManager profile.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for logging.
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [void]
  #
  def update_connection(context, name, resource)
    apply_connection_settings(context, name, resource)
  end

  # Deletes a persistent NetworkManager profile.
  #
  # @param name [String] The connection profile name.
  # @return [void]
  #
  def delete_connection(name)
    nmcli('connection', 'delete', name)
  end

  # Converts managed resource attributes into `nmcli connection modify` arguments.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for logging.
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [void]
  #
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

  # Validates IPv4 and IPv6 route declarations before writing them.
  #
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [void]
  #
  def validate_routes!(name, resource)
    validate_ip_routes!(name, resource, 4)
    validate_ip_routes!(name, resource, 6)
  end

  # Validates route conflicts for one address family.
  #
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @param family [Integer] Address family, either 4 or 6.
  # @return [void]
  #
  def validate_ip_routes!(name, resource, family)
    routes = resource[:"ipv#{family}_routes"] || []
    return if routes.empty?

    validate_route_sources!(name, routes, family)

    gateway = resource[:"ipv#{family}_gateway"]
    default_destination = ((family == 4) ? '0.0.0.0/0' : '::/0')

    route_description = "ipv#{family} route destination"
    raise Puppet::Error, "Connection '#{name}' declares both ipv#{family}_gateway and a default route in ipv#{family}_routes" if gateway && routes.any? { |route| same_network?(route_value(route, :destination), default_destination, name, route_description) }

    connected_networks = Array(resource[:"ipv#{family}_addresses"]).map do |address|
      canonical_network(address, name, "ipv#{family} address")
    end
    duplicate = routes.find do |route|
      connected_networks.include?(canonical_network(route_value(route, :destination), name, route_description))
    end
    return unless duplicate

    destination = route_value(duplicate, :destination)
    raise Puppet::Error, "Connection '#{name}' declares connected network '#{destination}' in ipv#{family}_routes; it is created automatically from ipv#{family}_addresses"
  end

  # Ensures route source addresses match the route address family.
  #
  # @param name [String] The connection profile name.
  # @param routes [Array<Hash>] Route declarations.
  # @param family [Integer] Address family, either 4 or 6.
  # @return [void]
  #
  def validate_route_sources!(name, routes, family)
    routes.each do |route|
      source = route_value(route, :source)
      next if source.nil?

      address = IPAddr.new(source)
      valid_family = (family == 4) ? address.ipv4? : address.ipv6?
      raise ArgumentError, 'address family does not match route' unless valid_family && !source.include?('/')
    rescue ArgumentError => e
      raise Puppet::Error, "Connection '#{name}' has invalid ipv#{family} route source '#{source}': #{e.message}"
    end
  end

  # Reads a route value from symbol or string keys.
  #
  # @param route [Hash] Route declaration.
  # @param key [Symbol] Route field to read.
  # @return [Object, nil] The route field value.
  #
  def route_value(route, key)
    route[key] || route[key.to_s]
  end

  # Compares two route destinations after canonical IP parsing.
  #
  # @param left [String] First CIDR value.
  # @param right [String] Second CIDR value.
  # @param name [String] The connection profile name.
  # @param description [String] Field description used in error messages.
  # @return [Boolean] Whether both values describe the same network.
  #
  def same_network?(left, right, name, description)
    canonical_network(left, name, description) == canonical_network(right, name, description)
  end

  # Parses a CIDR value into a stable network and prefix tuple.
  #
  # @param value [String] CIDR value to parse.
  # @param name [String] The connection profile name.
  # @param description [String] Field description used in error messages.
  # @return [Array(String, Integer)] Canonical network address and prefix length.
  #
  def canonical_network(value, name, description)
    network = IPAddr.new(value)
    [network.to_s, network.prefix]
  rescue ArgumentError => e
    raise Puppet::Error, "Connection '#{name}' has invalid #{description} '#{value}': #{e.message}"
  end

  # Reapplies a modified profile to its runtime device when requested.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for debug logging.
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [void]
  #
  def maybe_reapply_connection(context, name, resource)
    return unless resource[:reapply]

    device = resolve_reapply_device(name, resource)
    return if device.nil? || device.empty?

    nmcli('device', 'reapply', device)
  rescue Puppet::ExecutionFailure => e
    context.debug("Failed to reapply device '#{device}' for connection '#{name}': #{e}") if context
  end

  # Finds the device to use for `nmcli device reapply`.
  #
  # @param name [String] The connection profile name.
  # @param resource [Hash] Desired resource values.
  # @return [String, nil] Interface name, or nil when no device is known.
  #
  def resolve_reapply_device(name, resource)
    return resource[:device] if resource[:device] && !resource[:device].empty?

    output = nmcli('-t', '-f', 'connection.interface-name', 'connection', 'show', name).to_s.strip
    return nil if output.empty?

    output.split(':', 2).last.to_s.strip
  end

  # Formats a Puppet value as an `nmcli connection modify` value.
  #
  # @param value [Object] Value from the desired resource.
  # @return [String] Normalized value for nmcli.
  #
  def normalize_setting_value(value)
    return '' if value.nil?

    return value.map { |entry| format_route_entry(entry) }.compact.join(',') if value.is_a?(Array) && value.first.is_a?(Hash)

    value.is_a?(Array) ? value.join(',') : value.to_s
  end

  # Formats one route hash for the nmcli route syntax.
  #
  # @param entry [Hash] Route declaration.
  # @return [String, nil] Route string, or nil when no destination is present.
  #
  def format_route_entry(entry)
    destination = entry[:destination] || entry['destination']
    return nil if destination.nil? || destination.to_s.strip.empty?

    next_hop = entry[:next_hop] || entry['next_hop']
    metric = entry[:metric] || entry['metric']
    source = entry[:source] || entry['source']

    parts = [destination.to_s.strip]
    parts << next_hop.to_s.strip if next_hop && !next_hop.to_s.strip.empty?
    parts << metric.to_s.strip if metric && !metric.to_s.strip.empty?
    parts << "src=#{source.to_s.strip}" if source && !source.to_s.strip.empty?
    parts.join(' ')
  end

  # Splits a comma-separated profile value (e.g. "8.8.8.8,1.1.1.1") into an Array.
  # Returns nil when the value is absent or empty.
  #
  # @param value [String, nil] Comma-separated profile value.
  # @return [Array<String>, nil] Parsed values, or nil when absent.
  #
  def split_profile_list(value)
    return nil if value.nil? || value.strip.empty?

    result = value.split(',').map(&:strip).reject(&:empty?)
    result.empty? ? nil : result
  end

  # Parses the complete nmcli route list for one address family.
  #
  # @param value [String, nil] Comma-separated route list from nmcli.
  # @return [Array<Hash>] Parsed route declarations.
  #
  def parse_routes(value)
    return [] if value.nil? || value.strip.empty?

    value.split(',').map(&:strip).reject(&:empty?).map { |route| parse_route_entry(route) }.compact
  end

  # Parses one nmcli route entry into the resource hash shape.
  #
  # @param route [String] Route entry from nmcli.
  # @return [Hash, nil] Parsed route, or nil for blank input.
  #
  def parse_route_entry(route)
    parts = route.gsub(%r{\s*=\s*}, '=').split(%r{\s+})
    return nil if parts.empty?

    parsed = { 'destination' => parts.shift }
    attributes, positional = parts.partition { |part| part.include?('=') }

    if positional[0]&.match?(%r{\A\d+\z})
      parsed['metric'] = Integer(positional[0], 10)
    elsif positional[0] && !positional[0].empty?
      parsed['next_hop'] = positional[0]
      parsed['metric'] = Integer(positional[1], 10) if positional[1] && !positional[1].empty?
    end

    source = attributes.filter_map { |attribute| attribute.split('=', 2) if attribute.start_with?('src=') }.first
    parsed['source'] = source[1] if source && source[1] && !source[1].empty?
    parsed
  rescue ArgumentError
    # The metric is optional. Keep the usable route fields when nmcli reports
    # a metric that cannot be converted to an Integer.
    parsed
  end

  # Maps nmcli runtime state output to the resource enum.
  #
  # @param value [String, nil] Raw `GENERAL.STATE` value from nmcli.
  # @return [String] One of the supported `general_state` values.
  #
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
  # @example List profile names
  #   list_connections
  #
  def list_connections
    nmcli('-t', '-f', 'name', 'connection', 'show').split("\n").map(&:strip).reject(&:empty?)
  end

  # Fetches detailed information about a specific NetworkManager connection.
  # This method executes the `nmcli connection show <connection>` command.
  #
  # @param context [Puppet::ResourceApi::BaseContext] The context for error logging.
  # @param connection [String] The name of the connection to fetch.
  # @return [Hash] A hash representing the connection's properties.
  #
  # @example Fetch one profile
  #   fetch_connection_data(context, 'Home WiFi')
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

  # Executes the `nmcli` command with the specified arguments.
  # This method uses Puppet's `Puppet::Util::Execution.execute` to run the command.
  #
  # @param args [Array<String>] The arguments to pass to `nmcli`.
  # @return [String] The output of the command.
  #
  # @example Run nmcli with argv arguments
  #   nmcli('connection', 'show', 'lan0')
  #
  def nmcli(*args)
    command = Puppet::Util.which('nmcli')
    raise Puppet::Error, 'Unable to find nmcli in PATH' unless command

    Puppet::Util::Execution.execute([command] + args)
  end
end
