# frozen_string_literal: true

# @summary
#   Returns a hash of all active network connections managed by NetworkManager.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the device information using the `nmcli` command.
#   The fact includes the following fields for each device:
#   - active_path: The D-Bus path of the active connection.
#   - active: Whether the connection is currently active.
#   - autoconnect_priority: The priority of the connection for autoconnect.
#   - autoconnect: Whether the connection is set to autoconnect.
#   - dbus_path: The D-Bus path of the device.
#   - device: The name of the device.
#   - filename: The filename of the connection configuration.
#   - name: The name of the connection.
#   - readonly: Whether the connection is read-only.
#   - state: The state of the device (e.g., connected, disconnected).
#   - type: The type of the device (e.g., ethernet, wifi).
#   - uuid: The UUID of the connection.
#
Facter.add(:nm_active_connections) do
  confine kernel: 'Linux'

  setcode do
    Facter.value(:nm_all_connections).select do |_, connection|
      connection['active'] && connection['state'] == 'activated'
    end
  end
end
