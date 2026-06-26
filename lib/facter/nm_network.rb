# frozen_string_literal: true

# @summary
#   Returns the network connectivity status of the system using NetworkManager.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the network connectivity status using the `nmcli` command.
#
# @example Show whether NetworkManager networking is enabled
#   puppet facts show nm_network
#
# @return [String, nil] NetworkManager networking state, such as `enabled` or `disabled`.
#
Facter.add(:nm_network) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('nmcli') }

  setcode do
    Facter::Core::Execution.execute('nmcli -c no network').strip
  rescue StandardError
    nil
  end
end
