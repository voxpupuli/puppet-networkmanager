# frozen_string_literal: true

require 'spec_helper'

ensure_module_defined('Puppet::Provider::NetworkmanagerConnection')
require 'puppet/provider/networkmanager_connection/networkmanager_connection'

RSpec.describe Puppet::Provider::NetworkmanagerConnection::NetworkmanagerConnection do
  subject(:provider) { described_class.new }

  let(:context) { instance_double('Puppet::ResourceApi::BaseContext', 'context') }

  before do
    allow(context).to receive(:debug)
    allow(context).to receive(:err)
    allow(context).to receive(:notice)
  end

  describe '#get' do
    it 'returns all connections when no filter is provided' do
      allow(provider).to receive(:list_connections).and_return(%w[foo bar])
      allow(provider).to receive(:fetch_connection_data).with(context, 'foo').and_return(
        {
          name: 'foo',
          ensure: 'present',
        }
      )
      allow(provider).to receive(:fetch_connection_data).with(context, 'bar').and_return(
        {
          name: 'bar',
          ensure: 'present',
        }
      )

      expect(provider.get(context, nil)).to eq [
        {
          name: 'foo',
          ensure: 'present',
        },
        {
          name: 'bar',
          ensure: 'present',
        },
      ]
    end

    it 'normalizes and filters requested names' do
      allow(provider).to receive(:fetch_connection_data).with(context, 'foo').and_return(
        {
          name: 'foo',
          ensure: 'present',
        }
      )

      expect(provider.get(context, ['foo', nil, ''])).to eq [
        {
          name: 'foo',
          ensure: 'present',
        },
      ]
    end

    it 'returns an empty array when listing connections fails' do
      allow(provider).to receive(:list_connections).and_raise(Puppet::ExecutionFailure, 'nmcli failed')
      expect(context).to receive(:err).with(%r{nmcli failed})

      expect(provider.get(context, nil)).to eq([])
    end

    it 'logs when fetching a single connection fails' do
      allow(provider).to receive(:nmcli).with('-t', 'connection', 'show', 'foo').and_raise(Puppet::ExecutionFailure, 'connection missing')
      expect(context).to receive(:err).with(%r{Error fetching NetworkManager connection 'foo': connection missing})

      expect(provider.get(context, 'foo')).to eq([])
    end

    it 'normalizes general state values into the type enum' do
      allow(provider).to receive(:nmcli).with('-t', 'connection', 'show', 'foo').and_return(
        "GENERAL.STATE:100 (connected)\nconnection.type:wifi\nconnection.uuid:123\n"
      )

      expect(provider.get(context, 'foo')).to eq([
                                   {
                                     ensure: 'present',
                                     name: 'foo',
                                     type: 'wifi',
                                     device: nil,
                                     ipv4_method: nil,
                                     ipv4_addresses: nil,
                                     ipv4_dns: nil,
                                     ipv4_gateway: nil,
                                     ipv6_method: nil,
                                     ipv6_addresses: nil,
                                     ipv6_dns: nil,
                                     ipv6_gateway: nil,
                                     general_state: 'connected',
                                     uuid: '123',
                                   },
                                 ])
    end

    it 'reads addresses and dns from connection profile fields' do
      allow(provider).to receive(:nmcli).with('-t', 'connection', 'show', 'foo').and_return(
        "ipv4.addresses:192.168.1.10/24,192.168.1.11/24\nipv4.dns:1.1.1.1,8.8.8.8\n"
      )

      expect(provider.get(context, 'foo')).to eq([
                                   {
                                     ensure: 'present',
                                     name: 'foo',
                                     type: nil,
                                     device: nil,
                                     ipv4_method: nil,
                                     ipv4_addresses: ['192.168.1.10/24', '192.168.1.11/24'],
                                     ipv4_dns: ['1.1.1.1', '8.8.8.8'],
                                     ipv4_gateway: nil,
                                     ipv6_method: nil,
                                     ipv6_addresses: nil,
                                     ipv6_dns: nil,
                                     ipv6_gateway: nil,
                                     general_state: 'unknown',
                                     uuid: nil,
                                   },
                                 ])
    end
  end

  describe '#list_connections' do
    it 'filters blank entries from nmcli output' do
      allow(provider).to receive(:nmcli).with('-t', '-f', 'name', 'connection', 'show').and_return("foo\n\n bar \n\n")

      expect(provider.send(:list_connections)).to eq(%w[foo bar])
    end
  end

  describe '#set' do
    it 'creates a connection when resource is absent' do
      expect(context).to receive(:notice).with("Creating 'home'")
      expect(provider).to receive(:nmcli).with('connection', 'add', 'con-name', 'home', 'type', 'wifi', 'ifname', 'wlan0')
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'home',
                                               'connection.interface-name', 'wlan0',
                                               'ipv4.method', 'auto')

      provider.set(context, {
                     'home' => {
                       is: {},
                       should: {
                         name: 'home',
                         ensure: 'present',
                         type: 'wifi',
                         device: 'wlan0',
                         ipv4_method: 'auto',
                       },
                     },
                   })
    end

    it 'updates a connection when resource exists' do
      expect(context).to receive(:notice).with("Updating 'office'")
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'office',
                                               'ipv4.addresses', '10.0.0.10/24,10.0.0.11/24',
                                               'ipv4.dns', '1.1.1.1,8.8.8.8')

      provider.set(context, {
                     'office' => {
                       is: {
                         name: 'office',
                         ensure: 'present',
                       },
                       should: {
                         name: 'office',
                         ensure: 'present',
                         ipv4_addresses: ['10.0.0.10/24', '10.0.0.11/24'],
                         ipv4_dns: ['1.1.1.1', '8.8.8.8'],
                       },
                     },
                   })
    end

    it 'reapplies the device immediately when requested' do
      expect(context).to receive(:notice).with("Updating 'office'")
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'office',
                                               'connection.interface-name', 'enp0s8',
                                               'ipv4.method', 'auto')
      expect(provider).to receive(:nmcli).with('device', 'reapply', 'enp0s8')

      provider.set(context, {
                     'office' => {
                       is: {
                         name: 'office',
                         ensure: 'present',
                       },
                       should: {
                         name: 'office',
                         ensure: 'present',
                         device: 'enp0s8',
                         ipv4_method: 'auto',
                         reapply: true,
                       },
                     },
                   })
    end

    it 'resolves the interface name for reapply when device is omitted' do
      expect(context).to receive(:notice).with("Updating 'office'")
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'office',
                                               'ipv4.method', 'auto')
      expect(provider).to receive(:nmcli).with('-t', '-f', 'connection.interface-name', 'connection', 'show', 'office').and_return('connection.interface-name:enp0s8')
      expect(provider).to receive(:nmcli).with('device', 'reapply', 'enp0s8')

      provider.set(context, {
                     'office' => {
                       is: {
                         name: 'office',
                         ensure: 'present',
                       },
                       should: {
                         name: 'office',
                         ensure: 'present',
                         ipv4_method: 'auto',
                         reapply: true,
                       },
                     },
                   })
    end

    it 'deletes a connection when ensure is absent' do
      expect(context).to receive(:notice).with("Deleting 'old'")
      expect(provider).to receive(:nmcli).with('connection', 'delete', 'old')

      provider.set(context, {
                     'old' => {
                       is: {
                         name: 'old',
                         ensure: 'present',
                       },
                       should: {
                         name: 'old',
                         ensure: 'absent',
                       },
                     },
                   })
    end
  end
end
