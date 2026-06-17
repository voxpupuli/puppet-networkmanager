# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_network_connectivity'

describe :nm_network_connectivity, type: :fact do
  subject(:fact) { Facter.fact(:nm_network_connectivity) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter::Core::Execution).to receive(:which).with('nmcli').and_return('/usr/bin/nmcli')
    allow(Facter::Core::Execution).to receive(:execute).and_return('')
  end

  it 'returns nmcli connectivity status' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -c no network connectivity check')
      .and_return("full\n")

    expect(fact.value).to eq('full')
  end

  it 'returns nil when nmcli fails' do
    allow(Facter::Core::Execution).to receive(:execute)
      .and_raise(Puppet::ExecutionFailure, 'nmcli failed')

    expect(fact.value).to be_nil
  end

  it 'strips surrounding whitespace from nmcli output' do
    allow(Facter::Core::Execution).to receive(:execute)
      .with('nmcli -c no network connectivity check')
      .and_return(" full \n")

    expect(fact.value).to eq('full')
  end
end
