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
  Boolean $manage_nm_package = $networkmanager::manage_nm_package,
  String[1] $package_name    = $networkmanager::package_name,
  String[1] $package_version = $networkmanager::package_version,
) {
  if $manage_nm_package {
    package { $package_name:
      ensure => $package_version,
    }
  }
}
