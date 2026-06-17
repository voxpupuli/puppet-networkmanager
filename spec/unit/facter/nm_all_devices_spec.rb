# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_all_devices'

describe :nm_all_devices, type: :fact do
  subject(:fact) { Facter.fact(:nm_all_devices) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(Facter::Core::Execution).to receive(:execute).and_return('')
  end

  it 'returns parsed network devices' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -t -e yes -c no -f device,type,state,ip4-connectivity,ip6-connectivity,dbus-path,connection,con-uuid,con-path device')
      .and_return("eth0:ethernet:connected:full:full:/dbus/dev0:System eth0:uuid-1:/dbus/con0\n")

    expect(fact.value).to eq(
      {
        'eth0' => {
          'type' => 'ethernet',
          'state' => 'connected',
          'ip4_connectivity' => 'full',
          'ip6_connectivity' => 'full',
          'dbus_path' => '/dbus/dev0',
          'connection' => 'System eth0',
          'con_uuid' => 'uuid-1',
          'con_path' => '/dbus/con0',
        },
      }
    )
  end

  it 'returns an empty hash when nmcli fails' do
    allow(Facter::Core::Execution).to receive(:execute)
      .and_raise(Puppet::ExecutionFailure, 'nmcli failed')

    expect(fact.value).to be_nil
  end
end
