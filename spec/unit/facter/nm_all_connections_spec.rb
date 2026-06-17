# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_all_connections'

describe :nm_all_connections, type: :fact do
  subject(:fact) { Facter.fact(:nm_all_connections) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(Facter::Core::Execution).to receive(:execute).and_return('')
  end

  it 'returns parsed network connections' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return("foo:123:ethernet:yes:0:no:/dbus/1:yes:eth0:activated:/active/1:/etc/foo.nmconnection\n")

    expect(fact.value).to eq(
      {
        'foo' => {
          'uuid' => '123',
          'type' => 'ethernet',
          'autoconnect' => true,
          'autoconnect_priority' => '0',
          'readonly' => false,
          'dbus_path' => '/dbus/1',
          'active' => true,
          'device' => 'eth0',
          'state' => 'activated',
          'active_path' => '/active/1',
          'filename' => '/etc/foo.nmconnection',
        },
      }
    )
  end

  it 'keeps fields intact when the final value contains a colon' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return("foo:123:ethernet:yes:0:no:/dbus/1:yes:eth0:activated:/active/1:/etc/foo:profile.nmconnection\n")

    expect(fact.value['foo']['filename']).to eq('/etc/foo:profile.nmconnection')
  end
end
