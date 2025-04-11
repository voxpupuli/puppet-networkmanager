# frozen_string_literal: true

# @summary
#   Returns the version of NetworkManager installed on the system.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the version using the `NetworkManager` command.
#
Facter.add(:nm_version) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('NetworkManager') }

  setcode do
    Facter::Util::Resolution.exec("NetworkManager --version")
  end
end
