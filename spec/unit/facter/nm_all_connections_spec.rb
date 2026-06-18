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
      },
    )
  end

  it 'keeps fields intact when the final value contains a colon' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return("foo:123:ethernet:yes:0:no:/dbus/1:yes:eth0:activated:/active/1:/etc/foo:profile.nmconnection\n")

    expect(fact.value['foo']['filename']).to eq('/etc/foo:profile.nmconnection')
  end

  it 'skips blank lines in nmcli output' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return("\nfoo:123:ethernet:yes:0:no:/dbus/1:yes:eth0:activated:/active/1:/etc/foo.nmconnection\n\n")

    expect(fact.value.keys).to eq(['foo'])
  end

  it 'returns an empty hash when nmcli returns no connections' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return('')

    expect(fact.value).to eq({})
  end

  it 'returns an empty hash when nmcli fails' do
    allow(Facter::Core::Execution).to receive(:execute)
      .and_raise(Puppet::ExecutionFailure, 'nmcli failed')

    expect(fact.value).to be_nil
  end

  it 'does not add fact helpers to Object' do
    expect(Object.private_method_defined?(:fetch_connection_details)).to be(false)
    expect(Object.private_method_defined?(:split_profile_list)).to be(false)
  end

  it 'parses provider-settable profile fields' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
      .and_return("foo:123:ethernet:yes:0:no:/dbus/1:yes:eth0:activated:/active/1:/etc/foo.nmconnection\n")

    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t connection show foo')
      .and_return(<<~OUTPUT)
        ipv4.method:auto
        ipv4.addresses:192.168.1.10/24
        ipv4.dns:8.8.8.8,1.1.1.1
        ipv4.gateway:192.168.1.1
        ipv6.method:ignore
        ipv6.addresses:2001:db8::1/64
        ipv6.dns:2001:4860:4860::8888,2001:4860:4860::8844
        ipv6.gateway:fe80::1
      OUTPUT

    expect(fact.value['foo']).to include(
      'ipv4' => {
        'method' => 'auto',
        'address' => ['192.168.1.10/24'],
        'dns' => ['8.8.8.8', '1.1.1.1'],
        'gateway' => '192.168.1.1',
      },
      'ipv6' => {
        'method' => 'ignore',
        'address' => ['2001:db8::1/64'],
        'dns' => ['2001:4860:4860::8888', '2001:4860:4860::8844'],
        'gateway' => 'fe80::1',
      },
    )
  end
end
