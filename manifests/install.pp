# @summary Manages NetworkManager installation
#
# This class manages the installation of NetworkManager.
#
class networkmanager::install {
  if $networkmanager::manage_nm_package {
    package { $networkmanager::package_name:
      ensure => $networkmanager::package_version,
    }
  }
}
