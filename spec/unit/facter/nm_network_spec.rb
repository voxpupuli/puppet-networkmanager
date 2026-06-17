# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_network'

describe :nm_network, type: :fact do
  subject(:fact) { Facter.fact(:nm_network) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(Facter::Core::Execution).to receive(:execute).and_return('')
  end

  it 'returns nmcli network status' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -c no network')
      .and_return("enabled\n")

    expect(fact.value).to eq('enabled')
  end

  it 'returns nil when nmcli fails' do
    allow(Facter::Core::Execution).to receive(:execute)
      .and_raise(Puppet::ExecutionFailure, 'nmcli failed')

    expect(fact.value).to be_nil
  end

  it 'strips surrounding whitespace from nmcli output' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -c no network')
      .and_return(" enabled \n")

    expect(fact.value).to eq('enabled')
  end
end
