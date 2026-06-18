# Agent contribution guide

This file defines repository-specific instructions for AI-assisted work. It
supplements the Vox Pupuli and OpenVox Project
[AI usage policy](https://github.com/OpenVoxProject/.github/blob/main/AI_POLICY.md)
and the Vox Pupuli
[contribution guidelines](https://github.com/voxpupuli/.github/blob/master/CONTRIBUTING.md).

## Human accountability

- A human contributor must review, understand, and take responsibility for
  every proposed change before submission.
- Do not operate as a fully autonomous contributor. Stop and ask for human
  direction when a decision changes public behavior, compatibility, supported
  platforms, release metadata, or security-sensitive behavior.
- Never add a `Signed-off-by` trailer. DCO certification is a legal statement
  that only the human contributor may add.
- Disclose significant AI assistance. When asked to commit AI-assisted work,
  add an appropriate attribution trailer such as:

  ```text
  Co-authored-by: ChatGPT Codex <codex@openai.com>
  ```

- Do not push branches, open pull requests, publish releases, or modify remote
  state unless the human explicitly requests it.

## Scope and design

- Extend existing module patterns instead of introducing duplicate
  abstractions or new dependencies without a demonstrated need.
- Keep `networkmanager` as the public parameterized class. Its contained
  `install`, `config`, and `service` classes consume values from the main class.
- Preserve the class relationship:

  ```puppet
  Class['networkmanager::install']
  -> Class['networkmanager::config']
  ~> Class['networkmanager::service']
  ```

- Put shared Ruby implementation under `lib/puppet_x/networkmanager`.
- Keep Facter files focused on fact registration and use `PuppetX` helpers for
  reusable logic. Do not define helper methods on `Object`.
- Use argv arrays for command execution wherever possible. If a string command
  is unavoidable, shell-escape all external values.
- Preserve compatibility with the Vox Pupuli and operating-system ranges declared
  in `metadata.json`.

## Network safety

Network changes can disconnect test hosts and CI runners.

- Never modify or activate an existing management, default-route, NAT, or SSH
  interface in tests.
- Exercise connection resources with isolated, inactive profiles or dedicated
  test interfaces.
- Linux interface names must not exceed 15 characters.
- Acceptance tests must clean up profiles they create, including after failed
  examples where practical.
- Do not stop NetworkManager on a remotely accessed test host.
- Do not enable `reapply` in acceptance tests unless the target is a dedicated,
  disposable interface and runtime changes are the behavior under test.

## Testing

Add or update tests for every behavior change or bug fix. Refactoring and
documentation-only changes may reuse existing coverage when behavior is
unchanged.

Run the relevant focused tests while developing, then run:

```shell
bundle exec rake spec
bundle exec rake syntax
bundle exec rubocop
git diff --check
```

Acceptance tests use Beaker with Vagrant/libvirt in CI:

```shell
BEAKER_HYPERVISOR=vagrant_libvirt bundle exec rake beaker
```

Do not claim that acceptance tests passed unless they ran against a suitable VM.
If they cannot run locally, report that limitation explicitly.

## Commits and documentation

- Keep logically independent changes in separate commits, including separating
  refactoring from functional changes where practical.
- Use concise imperative commit subjects and explain motivation and changed
  behavior in the body when needed.
- Do not commit generated, temporary, commented-out, or unrelated files.
- Update `README.md` when public usage or behavior changes.
- Do not bump versions or prepare releases unless explicitly requested.
- Before committing, inspect the staged diff and ensure unrelated human changes
  are not included.

## Licensing and provenance

- This repository is licensed under AGPL-3.0. Ensure contributed code and
  reused material are compatible with that license.
- Do not copy substantial code from external sources without checking its
  license and recording required attribution.
- Prefer original implementations based on documented interfaces and existing
  repository patterns.
