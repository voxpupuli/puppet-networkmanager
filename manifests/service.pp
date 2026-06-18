# @summary Manages NetworkManager service
#
# This class manages the NetworkManager service.
#
class networkmanager::service {
  if $networkmanager::manage_nm_service_wait_online {
    service { $networkmanager::service_wait_online_name:
      ensure => $networkmanager::service_wait_online_ensure,
      enable => $networkmanager::service_wait_online_enable,
    }
  }
  if $networkmanager::manage_nm_service_dispatcher {
    service { $networkmanager::service_dispatcher_name:
      ensure => $networkmanager::service_dispatcher_ensure,
      enable => $networkmanager::service_dispatcher_enable,
    }
  }

  if $networkmanager::manage_nm_service {
    service { $networkmanager::service_name:
      ensure => $networkmanager::service_ensure,
      enable => $networkmanager::service_enable,
    }
  }
}
