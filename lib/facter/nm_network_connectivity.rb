# frozen_string_literal: true

# @summary
#   Returns the network connectivity status of the system using NetworkManager.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the network connectivity status using the `nmcli` command.
#
# @example Show NetworkManager connectivity state
#   puppet facts show nm_network_connectivity
#
# @return [String, nil] Connectivity state, such as `full`, `limited`, `portal`, or `none`.
#
Facter.add(:nm_network_connectivity) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('nmcli') }

  setcode do
    Facter::Core::Execution.execute('nmcli -c no network connectivity check').strip
  rescue StandardError
    nil
  end
end
