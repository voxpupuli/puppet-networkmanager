# NetworkManager module for Puppet

[![License](https://img.shields.io/badge/license-AGPL--3.0-blue.svg)](LICENSE)
[![Sponsored by betadots GmbH](https://img.shields.io/badge/Sponsored%20by-betadots%20GmbH-blue.svg)](https://www.betadots.de)

Manage NetworkManager packages, services, configuration files, and connection
profiles with Puppet.

> ⚠️ This module is under active development and is not yet recommended for
> production use.

> **AI usage disclosure:** Significant parts of this module have been written
> or refactored with the assistance of large language models (LLMs). Human
> contributors remain responsible for reviewing, understanding, testing, and
> maintaining all submitted code.

> **Contributor note:** AI agents and contributors using AI-assisted tooling
> must follow the repository-specific instructions in [AGENTS.md](AGENTS.md).

## Features

- Install the NetworkManager package.
- Manage the main NetworkManager service.
- Optionally manage the wait-online and dispatcher services.
- Optionally generate `NetworkManager.conf` from a hash.
- Create, update, and remove NetworkManager connection profiles through
  `nmcli`.
- Manage IPv4 and IPv6 addresses, DNS servers, gateways, and static routes.
- Reapply profile changes to an active device without reconnecting it. 🔄
- Reject redundant connected routes and duplicate default-route declarations.

## Usage

### Include the main class

```puppet
include networkmanager
```

By default, the class:

- installs the `NetworkManager` package;
- enables and starts the `NetworkManager` service;
- does not manage `/etc/NetworkManager/NetworkManager.conf`;
- does not manage the wait-online or dispatcher services.

### Manage NetworkManager.conf

The `networkmanager` class converts its `options` hash to INI format
using `puppet/extlib`.

```puppet
class { 'networkmanager':
  manage_nm_config => true,
  config_file      => '/etc/NetworkManager/NetworkManager.conf',
  options          => {
    'main' => {
      'plugins' => 'keyfile',
    },
    'logging' => {
      'level'   => 'INFO',
      'domains' => 'ALL',
    },
  },
}
```

## Managing connection profiles

The custom `networkmanager_connection` resource uses `nmcli connection` to
read and modify persistent NetworkManager profiles.

### Static IPv4 connection

```puppet
networkmanager_connection { 'lan0':
  ensure         => 'present',
  type           => '802-3-ethernet',
  device         => 'enp1s0',
  ipv4_method    => 'manual',
  ipv4_addresses => ['192.0.2.10/24'],
  ipv4_dns       => ['1.1.1.1', '8.8.8.8'],
  ipv4_gateway   => '192.0.2.1',
  ipv4_routes    => [],
  ipv6_method    => 'ignore',
  reapply        => true,
}
```

An empty route array explicitly removes all additional static routes. It is
normalized by the provider and is therefore idempotent.

If static routes should not be managed, omit `ipv4_routes` or `ipv6_routes`
instead.

### Additional static routes

```puppet
networkmanager_connection { 'lan0':
  ensure         => 'present',
  type           => '802-3-ethernet',
  device         => 'enp1s0',
  ipv4_method    => 'manual',
  ipv4_addresses => ['192.0.2.10/24'],
  ipv4_gateway   => '192.0.2.1',
  ipv4_routes    => [
    {
      destination => '198.51.100.0/24',
      next_hop    => '192.0.2.254',
      metric      => 100,
    },
    {
      destination => '203.0.113.0/24',
      next_hop    => '192.0.2.254',
      metric      => 200,
    },
  ],
  ipv6_method    => 'ignore',
  reapply        => true,
}
```

The `next_hop` and `metric` fields are optional. The metric applies to the
individual route.

### IPv6 connection and routes

```puppet
networkmanager_connection { 'ipv6-lan':
  ensure         => 'present',
  type           => '802-3-ethernet',
  device         => 'enp2s0',
  ipv4_method    => 'disabled',
  ipv6_method    => 'manual',
  ipv6_addresses => ['2001:db8:1::10/64'],
  ipv6_dns       => ['2001:4860:4860::8888'],
  ipv6_gateway   => '2001:db8:1::1',
  ipv6_routes    => [
    {
      destination => '2001:db8:2::/64',
      next_hop    => '2001:db8:1::fe',
      metric      => 100,
    },
  ],
  reapply        => true,
}
```

### Remove a connection

```puppet
networkmanager_connection { 'old-connection':
  ensure => 'absent',
}
```

## Routing rules

`ipv4_routes` and `ipv6_routes` are intended only for additional static
routes.

Do not declare the directly connected network. NetworkManager creates that
route automatically from the configured address:

```puppet
# Incorrect: 192.0.2.0/24 is already implied by 192.0.2.10/24.
ipv4_addresses => ['192.0.2.10/24'],
ipv4_routes    => [
  {
    destination => '192.0.2.0/24',
    next_hop    => '0.0.0.0',
  },
],
```

Do not define the default route in both `ipv4_gateway` and `ipv4_routes`:

```puppet
# Incorrect: these settings describe the same default route twice.
ipv4_gateway => '192.0.2.1',
ipv4_routes  => [
  {
    destination => '0.0.0.0/0',
    next_hop    => '192.0.2.1',
  },
],
```

Use `ipv4_gateway` or an explicit `0.0.0.0/0` route, but not both. The same
rule applies to `ipv6_gateway` and `::/0`.

The provider validates these conflicts before running `nmcli` and raises a
Puppet error instead of applying an ambiguous profile.

## Testing 🧪

Run the unit tests and syntax checks:

```shell
bundle exec rake spec
bundle exec rake syntax
```

Run the Vagrant test environment:

```shell
vagrant up
vagrant ssh
sudo -i
/opt/puppetlabs/bin/puppet apply /vagrant/test/example.pp
```

Run the same command a second time to verify idempotency. It should report no
changes. Inspect the resulting profile and routes:

```shell
nmcli connection show br-test
nmcli -f ipv4.routes connection show br-test
nmcli device status
```

The example creates an unused bridge first, which safely exercises profile creation and route parsing.
The Vagrant NAT interface remains available for SSH.
It is also possible to configure the enp0s9 interface and test with this.
See `test/example.pp` for details.

## Development status

The provider currently writes supported profile properties with
`nmcli connection modify` and can optionally execute `nmcli device reapply`.
It does not yet expose every NetworkManager setting or connection type
specific property.

Contributions and focused test cases are welcome. 🛠️
