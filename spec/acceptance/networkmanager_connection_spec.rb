# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'networkmanager_connection resource' do
  let(:test_profile) do
    {
      connection: 'puppet-acceptance',
      interface: 'br-puppet-acceptance',
    }
  end

  let(:networkmanager_manifest) do
    <<~PUPPET
      class { 'networkmanager':
        manage_nm_package => true,
        manage_nm_service => true,
      }
    PUPPET
  end

  let(:initial_manifest) do
    <<~PUPPET
      #{networkmanager_manifest}

      networkmanager_connection { '#{test_profile[:connection]}':
        ensure         => present,
        type           => bridge,
        device         => '#{test_profile[:interface]}',
        ipv4_method    => manual,
        ipv4_addresses => ['192.0.2.10/24'],
        ipv4_dns       => ['192.0.2.53'],
        ipv4_routes    => [
          {
            destination => '198.51.100.0/24',
            next_hop    => '192.0.2.1',
            metric      => 100,
          },
        ],
        ipv6_method    => disabled,
        reapply        => false,
        require        => Service['NetworkManager'],
      }
    PUPPET
  end

  let(:updated_manifest) do
    <<~PUPPET
      #{networkmanager_manifest}

      networkmanager_connection { '#{test_profile[:connection]}':
        ensure         => present,
        type           => bridge,
        device         => '#{test_profile[:interface]}',
        ipv4_method    => manual,
        ipv4_addresses => ['192.0.2.20/24'],
        ipv4_dns       => ['192.0.2.53', '198.51.100.53'],
        ipv4_routes    => [
          {
            destination => '203.0.113.0/24',
            next_hop    => '192.0.2.1',
            metric      => 200,
          },
        ],
        ipv6_method    => disabled,
        reapply        => false,
        require        => Service['NetworkManager'],
      }
    PUPPET
  end

  let(:absent_manifest) do
    <<~PUPPET
      networkmanager_connection { '#{test_profile[:connection]}':
        ensure => absent,
      }
    PUPPET
  end

  before do
    apply_manifest(networkmanager_manifest, catch_failures: true)
    shell("nmcli connection delete '#{test_profile[:connection]}'", acceptable_exit_codes: [0, 10])
  end

  after do
    shell("nmcli connection delete '#{test_profile[:connection]}'", acceptable_exit_codes: [0, 10])
  end

  context 'when creating a bridge profile' do
    it 'creates the requested profile idempotently' do
      apply_manifest(initial_manifest, catch_failures: true)
      apply_manifest(initial_manifest, catch_changes: true)

      connection_type = shell("nmcli --get-values connection.type connection show '#{test_profile[:connection]}'").stdout
      interface = shell("nmcli --get-values connection.interface-name connection show '#{test_profile[:connection]}'").stdout
      addresses = shell("nmcli --get-values ipv4.addresses connection show '#{test_profile[:connection]}'").stdout
      dns = shell("nmcli --get-values ipv4.dns connection show '#{test_profile[:connection]}'").stdout
      routes = shell("nmcli --get-values ipv4.routes connection show '#{test_profile[:connection]}'").stdout

      expect(connection_type).to match(%r{\Abridge\s*\z})
      expect(interface).to match(%r{\A#{test_profile[:interface]}\s*\z})
      expect(addresses).to include('192.0.2.10/24')
      expect(dns).to include('192.0.2.53')
      expect(routes).to include('198.51.100.0/24')
      expect(routes).to include('192.0.2.1')
      expect(routes).to match(%r{\b100\b})
    end
  end

  context 'when updating a bridge profile' do
    it 'updates the requested profile idempotently' do
      apply_manifest(initial_manifest, catch_failures: true)
      apply_manifest(updated_manifest, catch_failures: true)
      apply_manifest(updated_manifest, catch_changes: true)

      addresses = shell("nmcli --get-values ipv4.addresses connection show '#{test_profile[:connection]}'").stdout
      dns = shell("nmcli --get-values ipv4.dns connection show '#{test_profile[:connection]}'").stdout
      routes = shell("nmcli --get-values ipv4.routes connection show '#{test_profile[:connection]}'").stdout

      expect(addresses).to include('192.0.2.20/24')
      expect(addresses).not_to include('192.0.2.10/24')
      expect(dns).to include('192.0.2.53')
      expect(dns).to include('198.51.100.53')
      expect(routes).to include('203.0.113.0/24')
      expect(routes).to include('192.0.2.1')
      expect(routes).to match(%r{\b200\b})
      expect(routes).not_to include('198.51.100.0/24')
    end
  end

  context 'when deleting a bridge profile' do
    it 'deletes the requested profile idempotently' do
      apply_manifest(initial_manifest, catch_failures: true)
      apply_manifest(absent_manifest, catch_failures: true)
      apply_manifest(absent_manifest, catch_changes: true)

      result = shell("nmcli connection show '#{test_profile[:connection]}'", acceptable_exit_codes: [10])
      expect(result.exit_code).to eq 10
    end
  end
end
