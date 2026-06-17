# @summary Manages NetworkManager installation
#
# This class manages the installation of NetworkManager.
#
# @param manage_nm_package
#   Whether to manage the NetworkManager package.
#
# @param package_name
#   The name of the NetworkManager package.
#
# @param package_version
#   The version of the NetworkManager package.
#
class networkmanager::install (
  Boolean $manage_nm_package = true,
  String[1] $package_name    = 'NetworkManager',
  String[1] $package_version = 'installed',
) {
  if $manage_nm_package {
    package { $package_name:
      ensure => $package_version,
    }
  }
}
