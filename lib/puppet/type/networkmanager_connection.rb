# frozen_string_literal: true

require 'puppet/resource_api'

Puppet::ResourceApi.register_type(
  name: 'networkmanager_connection',
  docs: <<-EOS,
@summary a networkmanager_connection type
@example
networkmanager_connection { 'foo':
  ensure => 'present',
}

This type provides Puppet with the capabilities to manage NetworkManager connections.
EOS
  features: ['simple_get_filter'],
  attributes: {
    ensure: {
      type:    'Enum[present, absent]',
      desc:    'Whether this networkmanager_connection should exist on the target system.',
      default: 'present',
    },

    name: {
      type:    'String',
      desc:    'The name of the NetworkManager connection.',
      behaviour: :namevar,
    },

    type: {
      type:    'Enum[ethernet, "802-3-ethernet", loopback, wifi, vpn, bridge, bond, vlan]',
      desc:    'The type of the connection (e.g., ethernet, wifi, vpn).',
    },

    device: {
      type:    'Optional[String]',
      desc:    'The network interface this connection applies to (optional).',
    },

    ipv4_method: {
      type:    'Enum[auto, manual, disabled]',
      desc:    'The IPv4 configuration method (e.g., auto, manual, disabled).',
    },

    ipv4_addresses: {
      type:    'Optional[Array[Pattern[/\\A\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\/\\d{1,2}\\z/]]]',
      desc:    'An array of static IPv4 addresses (e.g., ["192.168.1.10/24", "192.168.1.11/24"]).',
    },

    ipv4_dns: {
      type:    'Optional[Array[Pattern[/\\A\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\z/]]]',
      desc:    'An array of DNS servers (e.g., ["8.8.8.8"]).',
    },

    ipv6_method: {
      type:    'Enum[auto, manual, disabled]',
      desc:    'The IPv6 configuration method (e.g., auto, manual, disabled).',
    },

    ipv6_addresses: {
      type:    'Optional[Array[String[1]]]',
      desc:    'An array of static IPv6 addresses (e.g., ["2001:db8::1/64", "2001:db8::2/64"]).',
    },

    ipv6_dns: {
      type:    'Optional[Array[String[1]]]',
      desc:    'An array of IPv6 DNS servers (e.g., ["2001:4860:4860::8888"]).',
    },

    general_state: {
      type:    'Enum[activated, unknown, down, connecting, connected, disconnecting]',
      desc:    'The state of the connection (e.g., up, down).',
      default: 'down',
    },

    uuid: {
      type:    'Optional[String]',
      desc:    'The UUID of the connection (if applicable).',
    },

    # ... weitere Attribute
  }
)
