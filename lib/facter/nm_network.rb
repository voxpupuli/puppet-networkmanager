# frozen_string_literal: true

# @summary
#   Returns the network connectivity status of the system using NetworkManager.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the network connectivity status using the `nmcli` command.
#
Facter.add(:nm_network) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('nmcli') }

  setcode do
    Facter::Core::Execution.execute('nmcli -c no network')
  end
end
