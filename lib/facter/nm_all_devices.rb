# frozen_string_literal: true

# @summary
#   Returns a hash of all network devices managed by NetworkManager.
#   This fact is only available on Linux systems with NetworkManager installed.
#   The fact retrieves the device information using the `nmcli` command.
#   The fact includes the following fields for each device:
#   - device: The name of the device.
#   - type: The type of the device (e.g., ethernet, wifi).
#   - state: The state of the device (e.g., connected, disconnected).
#   - ip4_connectivity: IPv4 connectivity status.
#   - ip6_connectivity: IPv6 connectivity status.
#   - dbus_path: The D-Bus path of the device.
#   - connection: The name of the connection associated with the device.
#   - con_uuid: The UUID of the connection.
#   - con_path: The D-Bus path of the connection.
#
Facter.add(:nm_all_devices) do
  confine kernel: 'Linux'
  confine { Facter::Core::Execution.which('nmcli') }

  setcode do
    nmcli_output = Facter::Core::Execution.execute('nmcli -t -e yes -c no -f device,type,state,ip4-connectivity,ip6-connectivity,dbus-path,connection,con-uuid,con-path device')
    devices = {}

    nmcli_output.each_line do |line|
      next if line.strip.empty?

      device, type, state, ip4_connectivity, ip6_connectivity, dbus_path, connection, con_uuid, con_path = line.strip.split(':')

      devices[device] = {}
      devices[device][:type] = type unless type.empty?
      devices[device][:state] = state unless state.empty?
      devices[device][:ip4_connectivity] = ip4_connectivity unless ip4_connectivity.empty?
      devices[device][:ip6_connectivity] = ip6_connectivity unless ip6_connectivity.empty?
      devices[device][:dbus_path] = dbus_path unless dbus_path.empty?
      devices[device][:connection] = connection unless connection.empty?
      devices[device][:con_uuid] = con_uuid unless con_uuid.empty?
      devices[device][:con_path] = con_path unless con_path.empty?
    end

    devices
  end
end
