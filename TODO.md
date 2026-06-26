# TODO and repository assessment

## Overall assessment

The repository has a solid foundation for version `0.1.0`. Its architecture,
tests, and safety rules are more disciplined than those of many young Puppet
modules. Before the module is recommended for production, several issues around
identity, validation, and error handling should be addressed.

## What the module already does well

- Separates package installation, configuration, and service management into
  `networkmanager::install`, `networkmanager::config`, and
  `networkmanager::service`.
- Preserves the class relationship:

  ```puppet
  Class['networkmanager::install']
  -> Class['networkmanager::config']
  ~> Class['networkmanager::service']
  ```

- Keeps `networkmanager` as the central public parameterized class.
- Uses the Puppet Resource API instead of a legacy provider implementation.
- Executes `nmcli` from the provider with argument arrays instead of shell
  command strings.
- Manages optional connection properties only when they are declared.
- Supports empty route arrays to remove existing static routes explicitly.
- Rejects duplicate default-route declarations and manually declared connected
  routes.
- Supports IPv4 and IPv6 addresses, DNS servers, gateways, routes, and preferred
  route source addresses.
- Reads the `src` route attribute back as `source`, allowing Puppet to remain
  idempotent.
- Keeps `reapply` disabled by default.
- Uses isolated bridge profiles in acceptance tests instead of modifying the
  management interface.
- Has useful provider unit coverage and CI integration for syntax, linting,
  unit tests, and Beaker.
- Provides concrete AI contribution and network safety rules in `AGENTS.md`.

## High-priority technical work

### 1. Use a reliable connection identity

NetworkManager permits multiple profiles with the same `connection.id`. The
module currently treats the profile name as a unique identifier:

- Profiles are listed and queried by name.
- Updates and deletions are performed by name.
- Facts use the name as a hash key and overwrite profiles with duplicate names.

This can result in the wrong profile being changed or deleted.

Possible solutions:

- Use the NetworkManager UUID as the resource namevar.
- Support `name` together with an optional `uuid` and reject ambiguous duplicate
  names.

This design should be resolved before recommending the module for production.

### 2. Implement complete IP validation

The current IPv4 patterns validate only the general string shape. Values such
as the following pass the Puppet type pattern:

```text
999.999.999.999/99
```

Most IPv6 properties currently accept any non-empty string. Provider validation
also validates addresses only indirectly in some route-related code paths.

Required improvements:

- Validate all addresses with `IPAddr`.
- Validate IPv4 octets and IPv4/IPv6 prefix ranges.
- Validate gateways, DNS servers, next hops, route sources, and destinations.
- Ensure every value belongs to the expected address family.
- Run validation independently of whether routes are configured.
- Consider reusable Puppet data type aliases for IPv4 and IPv6 values.

### 3. Define behavior for connection type changes

The connection `type` is exposed as a managed property, but the provider does
not write it during an update. Changing a profile from, for example, `ethernet`
to `bridge` can therefore cause repeated Puppet changes without changing the
actual profile.

Possible behaviors:

- Treat `type` as immutable and raise a clear error.
- Delete and recreate the profile when the type changes.

Automatic recreation changes public and potentially disruptive behavior and
requires an explicit design decision.

### 4. Roll back failed profile creation

Profile creation currently consists of two operations:

1. `nmcli connection add`
2. `nmcli connection modify`

If the second operation fails, an incomplete profile remains on the system.

The provider should capture the UUID of the newly created profile and remove
that exact profile if applying its settings fails.

### 5. Report `reapply` failures

Failures from `nmcli device reapply` are currently written only as debug
messages. Puppet can report a successful run even though the explicitly
requested runtime update failed.

Possible behaviors:

- Emit a warning while retaining the profile changes.
- Raise an error because `reapply => true` was explicitly requested.

This is a public behavior decision and should be agreed before implementation.

### 6. Make `nmcli` parsing escape-aware

Several parsers split terse `nmcli` output directly on `:` or `,`.
NetworkManager can escape separators in values, so profile names and more
complex route attributes can be parsed incorrectly.

Required improvements:

- Use `--terse`, `--escape yes`, and `--colors no` consistently.
- Implement correct parsing of escaped separators.
- Query only the fields required by each operation.
- Add parser tests for `\:`, `\\`, whitespace, and multiple route attributes.

## Facts

The current facts are useful but have scalability and diagnostic weaknesses:

- `nm_all_connections` executes an additional `nmcli` command for every
  connection profile.
- Profiles with duplicate names overwrite each other.
- Broad `rescue StandardError` handlers silently return `nil`.

Potential improvements:

- Structure connection facts by UUID instead of profile name.
- Retrieve the required data with as few `nmcli` calls as possible.
- Rescue only expected execution and parsing errors.
- Log failures through Facter debug logging.
- Evaluate whether the detailed connection facts should be opt-in because they
  run during every Facter and Puppet invocation.
- Use argument-array execution in the fact helper if supported by all declared
  Facter versions.

## Missing test coverage

Add tests for:

- Invalid IPv4 octets and prefix lengths.
- Invalid IPv6 addresses and prefix lengths.
- Incorrect address families for gateways, DNS servers, next hops, and route
  sources.
- A route `source` that is not one of the configured local addresses.
- Duplicate NetworkManager connection names.
- Changes to the type of an existing profile.
- Failure after a successful `connection add`.
- Failed `device reapply`.
- Escaped values in terse `nmcli` output.
- Routes with a metric and source but no next hop.
- Multiple addresses and a preferred source in an inactive acceptance profile.
- UUID-based update and deletion behavior.

Acceptance tests must continue to avoid activating default routes or modifying
management, NAT, or SSH interfaces.

## Release and documentation work

The following concrete issues currently exist:

- [ ] Add `CHANGELOG.md`; `bundle exec rake check_changelog` currently fails
      because the file is missing.
- [ ] Regenerate `REFERENCE.md` after the route `source` addition.
- [ ] Make `bundle exec rake strings:validate:reference` pass.
- [ ] Correct the invalid `@example` format in the Resource API type.
- [ ] Improve Puppet Strings documentation coverage.
- [ ] Correct `GCGConfig.project = 'puppet-extlib'` in `Rakefile`.
- [ ] Configure Dependabot for GitHub Actions and Bundler where appropriate.

## Potential features

Implement features incrementally instead of exposing arbitrary NetworkManager
properties immediately.

### Connection selection and activation

- `connection.autoconnect`
- `connection.autoconnect-priority`
- Explicit and carefully designed profile activation/deactivation
- Runtime state management separate from persistent profile management

### Routing

- IPv4 and IPv6 route tables
- Policy-routing rules
- `never-default`
- Global route metrics
- Additional supported route attributes

### DHCP and DNS

- `ignore-auto-dns`
- `ignore-auto-routes`
- DNS priority
- DHCP hostname and client identifier settings

### Ethernet

- MTU
- MAC address matching
- Cloned MAC address
- Wake-on-LAN settings

### VLAN, bridge, and bond support

- VLAN parent and VLAN ID
- Bridge ports
- Bond ports
- Controller/port relationships
- Connection-type-specific validation

Wi-Fi secrets, VPN support, and arbitrary generic NetworkManager properties
should be considered later because they add substantial complexity and
security-sensitive behavior.

## Suggested roadmap

### Short term

1. Add `CHANGELOG.md`.
2. Regenerate `REFERENCE.md`.
3. Correct the Puppet Strings warning.
4. Correct the release project name in `Rakefile`.
5. Add complete IP address validation and focused tests.

### Before production readiness

1. Define and implement UUID-based profile identity.
2. Define behavior for connection type changes.
3. Make profile creation transactional where practical.
4. Improve `reapply` error handling.
5. Make all `nmcli` parsing escape-aware.
6. Optimize and harden the custom facts.

### Subsequent feature development

1. Autoconnect settings.
2. Policy routing and route tables.
3. DHCP and DNS controls.
4. Ethernet properties.
5. VLAN support.
6. Bridge and bond port support.
