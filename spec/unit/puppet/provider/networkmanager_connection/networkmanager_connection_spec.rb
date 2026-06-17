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
end
