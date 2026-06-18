# frozen_string_literal: true

require 'spec_helper'

describe 'networkmanager' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile.with_all_deps }
      it { is_expected.to contain_class('networkmanager::install').that_comes_before('Class[networkmanager::config]') }
      it { is_expected.to contain_class('networkmanager::config').that_notifies('Class[networkmanager::service]') }
      it { is_expected.to contain_class('networkmanager::service') }
      it { is_expected.to contain_package('NetworkManager').with_ensure('installed') }
      it { is_expected.to contain_service('NetworkManager').with(ensure: 'running', enable: true) }

      context 'with custom package and service parameters' do
        let(:params) do
          {
            package_name: 'custom-networkmanager',
            package_version: '1.2.3',
            service_name: 'custom-networkmanager',
            service_ensure: 'stopped',
            service_enable: false,
          }
        end

        it { is_expected.to contain_package('custom-networkmanager').with_ensure('1.2.3') }
        it { is_expected.to contain_service('custom-networkmanager').with(ensure: 'stopped', enable: false) }
      end

      context 'with package and service management disabled' do
        let(:params) do
          {
            manage_nm_package: false,
            manage_nm_service: false,
          }
        end

        it { is_expected.not_to contain_package('NetworkManager') }
        it { is_expected.not_to contain_service('NetworkManager') }
      end

      context 'with configuration management enabled' do
        let(:params) do
          {
            manage_nm_config: true,
            config_file: '/tmp/NetworkManager.conf',
            config_file_mode: '0600',
            config_file_owner: 'network',
            config_file_group: 'network',
            options: {
              'main' => {
                'plugins' => 'keyfile',
              },
            },
          }
        end

        it do
          is_expected.to contain_file('/tmp/NetworkManager.conf').with(
            ensure: 'file',
            mode: '0600',
            owner: 'network',
            group: 'network',
            content: "# THIS FILE IS CONTROLLED BY PUPPET\n\n[main]\nplugins=\"keyfile\"\n",
          )
        end
      end

      context 'with auxiliary services enabled' do
        let(:params) do
          {
            manage_nm_service_wait_online: true,
            manage_nm_service_dispatcher: true,
            service_wait_online_name: 'nm-wait.service',
            service_wait_online_ensure: 'stopped',
            service_wait_online_enable: false,
            service_dispatcher_name: 'nm-dispatcher.service',
            service_dispatcher_ensure: 'running',
            service_dispatcher_enable: true,
          }
        end

        it { is_expected.to contain_service('nm-wait.service').with(ensure: 'stopped', enable: false) }
        it { is_expected.to contain_service('nm-dispatcher.service').with(ensure: 'running', enable: true) }
      end
    end
  end
end
