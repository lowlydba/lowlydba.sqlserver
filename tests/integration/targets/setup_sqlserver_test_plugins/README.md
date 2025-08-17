# Test plugins: run PowerShell on the controller (Diátaxis)<!-- omit in toc -->

These test-only plugins provide a custom connection and shell layer to run Ansible PowerShell modules directly on the controller with `pwsh` (Linux/macOS/Windows) without modifying module code.

- [Tutorials (start here)](#tutorials-start-here)
- [How-to guides (recipes)](#how-to-guides-recipes)
  - [Fix SystemPolicy errors on Linux/macOS (ansible-core 2.19+)](#fix-systempolicy-errors-on-linuxmacos-ansible-core-219)
  - [Fall back to remote Windows execution](#fall-back-to-remote-windows-execution)
- [Reference (what it is)](#reference-what-it-is)
- [Explanation (background, rationale)](#explanation-background-rationale)
  - [Background](#background)
  - [Compatibility notes (ansible-core 2.19+)](#compatibility-notes-ansible-core-219)
  - [Scope and impact](#scope-and-impact)
  - [Troubleshooting](#troubleshooting)

## Tutorials (start here)

Goal: run collection integration tests that exercise PowerShell modules locally on the controller via `pwsh`.

Steps (high level):

- Ensure `pwsh` (PowerShell 7+) is installed on the controller.
- Run the collection's integration tests; this target auto-enables the custom plugins in this folder.
- Tests execute PowerShell modules on the controller, while those modules still manage remote SQL Server hosts as usual.

Notes:

- These plugins are scoped to this integration test target and are not installed with the collection.
- Prefer a Windows host if you want the standard, remote PowerShell execution path.

## How-to guides (recipes)

### Fix SystemPolicy errors on Linux/macOS (ansible-core 2.19+)

Nothing for you to change: the test shell plugin (`shell_plugins/pwsh.py`) automatically injects a small compatibility stub before any PowerShell code runs. If you still hit errors:

- Confirm this test shell plugin is active for your run (this target enables it by default).
- Ensure the script is sent with `-EncodedCommand` (not stdin), which the plugin uses by default.

### Fall back to remote Windows execution

If local controller execution isn't desired, point your playbooks at a Windows host so modules run remotely as usual.

## Reference (what it is)

Components in this target:

- `shell_plugins/pwsh.py` — custom PowerShell shell plugin.
  - Encodes scripts with `-EncodedCommand` and prepends a compatibility stub when needed.
  - For ansible-core < 2.13 includes a local bootstrap path to load test module utils for cross-platform use.
- `connection_plugins/` — connection helper used in these tests.
- `module_utils/` — local test-only helpers used by the bootstrap path for older ansible-core.

Behavior/Options (subset):

- Typical PowerShell shell options such as `async_dir`, `remote_tmp`, `environment` (see the plugin's `DOCUMENTATION` block).
- No persistent user profiles or global state are modified.

## Explanation (background, rationale)

### Background

PowerShell modules in this collection are typically run on a remote Windows host. For CI and developer convenience, we sometimes run the modules on the controller via `pwsh` instead.

### Compatibility notes (ansible-core 2.19+)

Starting with ansible-core 2.19.0b5, the internal PowerShell wrappers reference `[SystemPolicy]` very early (e.g., `SystemPolicy.ExecutionPolicy`, `SystemPolicy::GetSystemLockdownPolicy()`). PowerShell Core on Linux/macOS does not provide that type.

The test shell plugin injects a minimal stub only when `[SystemPolicy]` is missing:

- Defines `SystemPolicy` with an `ExecutionPolicy` enum (Bypass, Unrestricted, RemoteSigned, AllSigned, Restricted).
- Provides a static `GetSystemLockdownPolicy()` that returns `"None"` (so checks like `-eq 'Enforce'` remain false).
- On Windows PowerShell, the real `[SystemPolicy]` exists; the stub is not injected.

### Scope and impact

- Stub is local to these integration tests; it does not modify ansible-core or collection modules.
- Behavior for ansible-core < 2.19 is unchanged; the stub is a no-op if not needed.

### Troubleshooting

- If you see CLIXML errors mentioning `[SystemPolicy]`, ensure this test shell plugin is active and that scripts are sent via `-EncodedCommand`.
- Editor warnings about unresolved `ansible.*` imports inside the plugin are local environment issues and do not affect runtime under ansible-core.

Supportability:

- These plugins are experimental and test-scoped. They avoid changing collection modules and keep behavior deterministic for CI.
