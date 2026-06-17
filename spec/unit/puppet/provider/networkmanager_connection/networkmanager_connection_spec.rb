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
      allow(provider).to receive(:fetch_connection_data).with('foo').and_return(
        {
          name: 'foo',
          ensure: 'present',
        }
      )
      allow(provider).to receive(:fetch_connection_data).with('bar').and_return(
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
      allow(provider).to receive(:fetch_connection_data).with('foo').and_return(
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
  end

  describe '#set' do
    it 'creates a connection when resource is absent' do
      expect(context).to receive(:notice).with("Creating 'home'")
      expect(provider).to receive(:nmcli).with('connection', 'add', 'con-name', 'home', 'type', 'wifi', 'ifname', 'wlan0')
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'home',
                                               'connection.interface-name', 'wlan0',
                                               'ipv4.method', 'auto')

      provider.set(context, [
                     {
                       is: {},
                       should: {
                         name: 'home',
                         ensure: 'present',
                         type: 'wifi',
                         device: 'wlan0',
                         ipv4_method: 'auto',
                       },
                     },
                   ])
    end

    it 'updates a connection when resource exists' do
      expect(context).to receive(:notice).with("Updating 'office'")
      expect(provider).to receive(:nmcli).with('connection', 'modify', 'office',
                                               'ipv4.addresses', '10.0.0.10/24,10.0.0.11/24',
                                               'ipv4.dns', '1.1.1.1,8.8.8.8')

      provider.set(context, [
                     {
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
                   ])
    end

    it 'deletes a connection when ensure is absent' do
      expect(context).to receive(:notice).with("Deleting 'old'")
      expect(provider).to receive(:nmcli).with('connection', 'delete', 'old')

      provider.set(context, [
                     {
                       is: {
                         name: 'old',
                         ensure: 'present',
                       },
                       should: {
                         name: 'old',
                         ensure: 'absent',
                       },
                     },
                   ])
    end
  end
end
