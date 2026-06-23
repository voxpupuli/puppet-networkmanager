# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_version'

describe :nm_version, type: :fact do
  subject(:fact) { Facter.fact(:nm_version) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
    allow(Facter::Core::Execution).to receive(:which).and_return('/usr/sbin/NetworkManager')
  end

  it 'returns NetworkManager version' do
    allow(Facter::Util::Resolution).to receive(:exec)
      .with('NetworkManager --version')
      .and_return("1.51.6-1.el9\n")

    expect(fact.value).to eq('1.51.6-1.el9')
  end

  it 'returns nil when NetworkManager fails' do
    allow(Facter::Util::Resolution).to receive(:exec)
      .and_raise(Puppet::ExecutionFailure, 'NetworkManager failed')

    expect(fact.value).to be_nil
  end

  it 'strips surrounding whitespace from version output' do
    allow(Facter::Util::Resolution).to receive(:exec)
      .with('NetworkManager --version')
      .and_return(" 1.51.6-1.el9 \n")

    expect(fact.value).to eq('1.51.6-1.el9')
  end
end
