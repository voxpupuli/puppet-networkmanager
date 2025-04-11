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
  Boolean $manage_nm_service     = $networkmanager::manage_nm_service,
  Boolean $manage_nm_service_wait_online = $networkmanager::manage_nm_service_wait_online,
  Boolean $manage_nm_service_dispatcher  = $networkmanager::manage_nm_service_dispatcher,

  String[1] $service_name = $networkmanager::service_name,
  String[1] $service_ensure = $networkmanager::service_ensure,
  String[1] $service_enable = $networkmanager::service_enable,

  String[1] $service_wait_online_name = $networkmanager::service_wait_online_name,
  String[1] $service_wait_online_ensure = $networkmanager::service_wait_online_ensure,
  String[1] $service_wait_online_enable = $networkmanager::service_wait_online_enable,

  String[1] $service_dispatcher_name = $networkmanager::service_dispatcher_name,
  String[1] $service_dispatcher_ensure = $networkmanager::service_dispatcher_ensure,
  String[1] $service_dispatcher_enable = $networkmanager::service_dispatcher_enable,
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
