# frozen_string_literal: true

require 'spec_helper_acceptance'

describe 'networkmanager class' do
  let(:manifest) do
    <<~PUPPET
      class { 'networkmanager':
        manage_nm_package => true,
        manage_nm_service => true,
        service_ensure    => 'running',
        service_enable    => true,
      }
    PUPPET
  end

  it 'applies idempotently' do
    apply_manifest(manifest, catch_failures: true)
    apply_manifest(manifest, catch_changes: true)
  end

  describe package('NetworkManager') do
    it { is_expected.to be_installed }
  end

  describe service('NetworkManager') do
    it { is_expected.to be_running }
    it { is_expected.to be_enabled }
  end
end
