# @summary Manages NetworkManager service
#
# This class manages the NetworkManager service.
#
# @param manage_nm_service
#   Whether to manage the NetworkManager service.
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
# @param manage_nm_service_wait_online
#   Whether to manage the NetworkManager-wait-online service.
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
# @param manage_nm_service_dispatcher
#   Whether to manage the NetworkManager-dispatcher service.
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
class networkmanager::service (
  Boolean $manage_nm_service = true,
  Boolean $manage_nm_service_wait_online = false,
  Boolean $manage_nm_service_dispatcher = false,

  String[1] $service_name = 'NetworkManager',
  String[1] $service_ensure = 'running',
  Boolean $service_enable = true,

  String[1] $service_wait_online_name = 'NetworkManager-wait-online.service',
  String[1] $service_wait_online_ensure = 'running',
  Boolean $service_wait_online_enable = true,

  String[1] $service_dispatcher_name = 'NetworkManager-dispatcher.service',
  String[1] $service_dispatcher_ensure = 'stopped',
  Boolean $service_dispatcher_enable = true,
) {
  if $manage_nm_service_wait_online {
    service { $service_wait_online_name:
      ensure => $service_wait_online_ensure,
      enable => $service_wait_online_enable,
    }
  }
  if $manage_nm_service_dispatcher {
    service { $service_dispatcher_name:
      ensure => $service_dispatcher_ensure,
      enable => $service_dispatcher_enable,
    }
  }

  if $manage_nm_service {
    service { $service_name:
      ensure => $service_ensure,
      enable => $service_enable,
    }
  }
}
