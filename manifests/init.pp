# @summary Manages NetworkManager
#
# This class manages the NetworkManager service and configuration.
#
# @param config_file
#   The path to the NetworkManager configuration file.
#
# @param config_file_mode
#   The mode of the NetworkManager configuration file.
#
# @param config_file_owner
#   The owner of the NetworkManager configuration file.
#
# @param config_file_group
#   The group of the NetworkManager configuration file.
#
# @param manage_nm_config
#   Whether to manage the NetworkManager configuration file.
#
# @param manage_nm_package
#   Whether to manage the NetworkManager package.
#
# @param manage_nm_service
#   Whether to manage the NetworkManager service.
#
# @param manage_nm_service_wait_online
#   Whether to manage the NetworkManager-wait-online service.
#
# @param manage_nm_service_dispatcher
#   Whether to manage the NetworkManager-dispatcher service.
#
# @param package_name
#   The name of the NetworkManager package.
#
# @param package_version
#   The version of the NetworkManager package.
#
# @param service_name
#   The name of the NetworkManager service.
#
# @param service_ensure
#   The desired state of the NetworkManager service.
#
# @param service_enable
#   Whether to enable the NetworkManager service at boot.
#
# @param service_wait_online_name
#   The name of the NetworkManager-wait-online service.
#
# @param service_wait_online_ensure
#   The desired state of the NetworkManager-wait-online service.
#
# @param service_wait_online_enable
#   Whether to enable the NetworkManager-wait-online service at boot.
#
# @param service_dispatcher_name
#   The name of the NetworkManager-dispatcher service.
#
# @param service_dispatcher_ensure
#   The desired state of the NetworkManager-dispatcher service.
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

  String[1] $config_file = '/etc/NetworkManager/NetworkManager.conf',
  String[1] $config_file_mode = '0644',
  String[1] $config_file_owner = 'root',
  String[1] $config_file_group = 'root',

  String[1] $package_name = 'NetworkManager',
  String[1] $package_version = 'installed',

  String[1] $service_name = 'NetworkManager',
  String[1] $service_ensure = 'running',
  String[1] $service_enable = true,

  String[1] $service_wait_online_name = "${service_name}-wait-online.service",
  String[1] $service_wait_online_ensure = 'running',
  String[1] $service_wait_online_enable = true,

  String[1] $service_dispatcher_name = "${service_name}-dispatcher.service",
  String[1] $service_dispatcher_ensure = 'stopped',
  String[1] $service_dispatcher_enable = true,
) {
  include networkmanager::install
  include networkmanager::config
  include networkmanager::service
}
