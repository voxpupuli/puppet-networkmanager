# @summary Manages NetworkManager
#
# This class manages the NetworkManager service and configuration.
#
# @example Manage the package and service only
#   include networkmanager
#
# @example Manage NetworkManager.conf content
#   class { 'networkmanager':
#     manage_nm_config => true,
#     options          => {
#       'main'    => { 'plugins' => 'keyfile' },
#       'logging' => { 'level' => 'INFO' },
#     },
#   }
#
# @param config_file
#   Absolute path to the NetworkManager configuration file managed when
#   `manage_nm_config` is true. Example: `/etc/NetworkManager/NetworkManager.conf`.
#
# @param config_file_mode
#   File mode for `config_file`. Example: `0644`.
#
# @param config_file_owner
#   Owner for `config_file`. Example: `root`.
#
# @param config_file_group
#   Group for `config_file`. Example: `root`.
#
# @param manage_nm_config
#   Whether to manage `config_file` from the `options` hash.
#
# @param manage_nm_package
#   Whether to manage the NetworkManager package resource.
#
# @param manage_nm_service
#   Whether to manage the main NetworkManager service resource.
#
# @param manage_nm_service_wait_online
#   Whether to manage the NetworkManager wait-online service.
#
# @param manage_nm_service_dispatcher
#   Whether to manage the NetworkManager dispatcher service.
#
# @param options
#   INI-style settings rendered to `config_file` when `manage_nm_config` is true.
#   Example: `{ 'logging' => { 'level' => 'INFO' } }`.
#
# @param package_name
#   Package resource title for NetworkManager. Example: `NetworkManager`.
#
# @param package_version
#   Desired package ensure value. Example: `installed` or `latest`.
#
# @param service_name
#   Main NetworkManager service resource title. Example: `NetworkManager`.
#
# @param service_ensure
#   Desired state of the main NetworkManager service. Example: `running`.
#
# @param service_enable
#   Whether to enable the main NetworkManager service at boot.
#
# @param service_wait_online_name
#   Wait-online service resource title. Example: `NetworkManager-wait-online.service`.
#
# @param service_wait_online_ensure
#   Desired state of the wait-online service. Example: `running`.
#
# @param service_wait_online_enable
#   Whether to enable the NetworkManager-wait-online service at boot.
#
# @param service_dispatcher_name
#   Dispatcher service resource title. Example: `NetworkManager-dispatcher.service`.
#
# @param service_dispatcher_ensure
#   Desired state of the dispatcher service. Example: `stopped`.
#
# @param service_dispatcher_enable
#   Whether to enable the NetworkManager-dispatcher service at boot.
#
class networkmanager (
  Boolean $manage_nm_config = false,
  Boolean $manage_nm_package = true,
  Boolean $manage_nm_service = true,
  Boolean $manage_nm_service_wait_online = false,
  Boolean $manage_nm_service_dispatcher = false,

  Hash $options = {},
  String[1] $config_file = '/etc/NetworkManager/NetworkManager.conf',
  String[1] $config_file_mode = '0644',
  String[1] $config_file_owner = 'root',
  String[1] $config_file_group = 'root',

  String[1] $package_name = 'NetworkManager',
  String[1] $package_version = 'installed',

  String[1] $service_name = 'NetworkManager',
  String[1] $service_ensure = 'running',
  Boolean $service_enable = true,

  String[1] $service_wait_online_name = "${service_name}-wait-online.service",
  String[1] $service_wait_online_ensure = 'running',
  Boolean $service_wait_online_enable = true,

  String[1] $service_dispatcher_name = "${service_name}-dispatcher.service",
  String[1] $service_dispatcher_ensure = 'stopped',
  Boolean $service_dispatcher_enable = true,
) {
  contain networkmanager::install
  contain networkmanager::config
  contain networkmanager::service

  Class['networkmanager::install']
  -> Class['networkmanager::config']
  ~> Class['networkmanager::service']
}
