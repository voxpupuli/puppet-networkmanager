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
  Boolean $manage_nm_config = false,
  String[1] $config_file = '/etc/NetworkManager/NetworkManager.conf',
  String $config_file_mode = '0644',
  String $config_file_owner = 'root',
  String $config_file_group = 'root',
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
