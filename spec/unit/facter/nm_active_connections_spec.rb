# frozen_string_literal: true

require 'spec_helper'
require 'facter'
require 'facter/nm_active_connections'

describe :nm_active_connections, type: :fact do
  subject(:fact) { Facter.fact(:nm_active_connections) }

  before do
    Facter.clear
    Facter.add(:kernel) { setcode { 'Linux' } }
    allow(Facter).to receive(:value).and_call_original
    allow(Facter).to receive(:value).with(:kernel).and_return('Linux')
    allow(Facter.fact(:kernel)).to receive(:value).and_return('Linux')
  end

  it 'returns only activated and active connections' do
    allow(Facter).to receive(:value).with(:nm_all_connections).and_return(
      {
        'foo' => { active: true, state: 'activated' },
        'bar' => { active: false, state: 'activated' },
        'baz' => { active: true, state: 'deactivated' },
      }
    )

    expect(fact.value).to eq(
      {
        'foo' => { 'active' => true, 'state' => 'activated' },
      }
    )
  end

  it 'handles string-keyed input from nm_all_connections' do
    allow(Facter).to receive(:value).with(:nm_all_connections).and_return(
      {
        'foo' => { 'active' => true, 'state' => 'activated', 'uuid' => '123', 'ipv4' => { 'dns' => ['8.8.8.8'] } },
      }
    )

    expect(fact.value).to eq(
      {
        'foo' => { 'active' => true, 'state' => 'activated', 'uuid' => '123', 'ipv4' => { 'dns' => ['8.8.8.8'] } },
      }
    )
  end

  it 'returns an empty hash when no connection is active' do
    allow(Facter).to receive(:value).with(:nm_all_connections).and_return(
      {
        'foo' => { active: true, state: 'deactivated' },
        'bar' => { active: false, state: 'activated' },
      }
    )

    expect(fact.value).to eq({})
  end

  it 'returns nil when nm_all_connections fails' do
    allow(Facter).to receive(:value).with(:nm_all_connections).and_return(nil)

    expect(fact.value).to be_nil
  end
end
