# frozen_string_literal: true

require 'spec_helper'
require 'puppet/type/networkmanager_connection'

RSpec.describe 'the networkmanager_connection type' do
  it 'loads' do
    expect(Puppet::Type.type(:networkmanager_connection)).not_to be_nil
  end
end
