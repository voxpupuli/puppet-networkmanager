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
end
