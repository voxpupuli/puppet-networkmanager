# @summary Manages NetworkManager configuration
#
# This class manages the NetworkManager configuration file.
#
class networkmanager::config {
  if $networkmanager::manage_nm_config {
    file { $networkmanager::config_file:
      ensure  => file,
      mode    => $networkmanager::config_file_mode,
      owner   => $networkmanager::config_file_owner,
      group   => $networkmanager::config_file_group,
      content => $networkmanager::options.extlib::to_ini,
    }
  }
}
