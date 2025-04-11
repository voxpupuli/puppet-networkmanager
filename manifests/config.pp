# @summary Manages NetworkManager configuration
#
# This class manages the NetworkManager configuration file.
#
# @param options
#   A hash of options to be included in the configuration file.
# @param manage_nm_config
#   Whether to manage the NetworkManager configuration file.
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
class networkmanager::config (
  Hash $options = {},
  Boolean $manage_nm_config = $networkmanager::manage_nm_config,
  String[1] $config_file = $networkmanager::config_file,
  String $config_file_mode = $networkmanager::config_file_mode,
  String $config_file_owner = $networkmanager::config_file_owner,
  String $config_file_group = $networkmanager::config_file_group,
) {
  if $manage_nm_config {
    file { $config_file:
      ensure  => file,
      mode    => $config_file_mode,
      owner   => $config_file_owner,
      group   => $config_file_group,
      content => $options.extlib::to_ini,
    }
  }
}
