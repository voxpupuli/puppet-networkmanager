# frozen_string_literal: true

# @summary
#   Returns a hash of all network connections managed by NetworkManager.
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
Facter.add(:nm_all_connections) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('nmcli') }

  setcode do
    nmcli_output = Facter::Core::Execution.execute('nmcli -t -f name,uuid,type,autoconnect,autoconnect-priority,readonly,dbus-path,active,device,state,active-path,filename con show')
    connections = {}

    nmcli_output.each_line do |line|
      next if line.strip.empty?

      name,uuid,type,autoconnect,autoconnect_priority,readonly,dbus_path,active,device,state,active_path,filename = line.strip.split(':')

      connections[name] = {}
      connections[name][:uuid] = uuid unless uuid.empty?
      connections[name][:type] = type unless type.empty?
      connections[name][:autoconnect] = autoconnect == 'yes' unless autoconnect.empty?
      connections[name][:autoconnect_priority] = autoconnect_priority unless autoconnect_priority.empty?
      connections[name][:readonly] = readonly == 'yes' unless readonly.empty?
      connections[name][:dbus_path] = dbus_path unless dbus_path.empty?
      connections[name][:active] = active == 'yes' unless active.empty?
      connections[name][:device] = device unless device.empty?
      connections[name][:state] = state unless state.empty?
      connections[name][:active_path] = active_path unless active_path.empty?
      connections[name][:filename] = filename unless filename.empty?
    end

    connections
  end
end
