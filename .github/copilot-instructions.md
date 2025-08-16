Purpose

This repository is an Ansible Collection for managing SQL Server using the PowerShell dbatools module. Modules are implemented in PowerShell (*.ps1) with small Python documentation shims (*.py). The collection targets cross-platform control nodes (Linux/macOS/Windows) but talks to SQL Server (Windows-style paths, SMO) on Windows servers.

Primary languages & tools

- PowerShell (modules under `plugins/modules/*.ps1` and module_utils/*.psm1)
- Python (module documentation files under `plugins/modules/*.py`)
- YAML (integration tests under `tests/integration/targets/**`)
- dbatools PowerShell module (runtime dependency)

High-level guidance for Copilot edits/suggestions

- Preserve idempotency. Modules must set `module.Result.changed` only when actual server-side state changes. Prefer reading server state with dbatools `Get-*` functions and comparing to the desired state.
- Prefer using dbatools functions (Get-DbaAgentJob, Set-DbaAgentJob, Get-DbaAgentJobOutputFile, Set-DbaAgentJobOutputFile, etc.) rather than manipulating SMO internals directly.
- Prefer using PSDefaultParameterValues when possible to avoid redundant parameter parsing.
- Use the shared helpers in `plugins/module_utils/_SqlServerUtils.psm1` (e.g., `Get-LowlyDbaSqlServerAuthSpec`, `Get-SqlCredential`, `ConvertTo-SerializableObject`) instead of reimplementing them.
- For cross-platform code running on Linux control nodes: avoid using Windows-only path APIs when comparing paths returned by SQL Server tools. Either let the server report the canonical value and compare server-before vs server-after, or perform simple string normalization that is safe on all hosts.
- Respect `check_mode` by not performing actual changes and by returning what would be changed.
- When calling dbatools setters that mutate SMO state, prefer to re-read the server-reported value (Get-*) and use that for the module `data` return and change detection. If SMO latency is a concern, implement a small retry (few attempts with short sleeps) when reading back the value — do not add long sleeps in tests.
- When serializing SMO objects for `module.Result.data`, use `ConvertTo-SerializableObject` to avoid recursion and platform-specific type issues.

Code style & constraints

- Keep PowerShell code compatible with PowerShell Core and Windows PowerShell where practical.
- Use Ansible's AnsibleModule patterns: module creation via `[Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))` and `ExitJson()` / `FailJson()` for outputs.
- Avoid printing or writing secrets; mark password options `no_log` in specs.

Testing guidance

- Integration tests live in `tests/integration/targets/*`. Tests expect a Windows SQL Server target (CI uses ephemeral VMs/containers). Running tests locally requires a reachable SQL Server instance and credentials in `tests/integration/integration_config.yml`.
- Add/adjust unit tests for any helper logic in `plugins/module_utils` if you change normalization/serialization.
- Keep tests deterministic: avoid brittle timing assumptions; use short retries for SMO refresh instead of fixed long sleeps.

PR reviewer checklist (help Copilot produce PRs that pass CI)

- Ensure modules are idempotent and `changed` is correct.
- Ensure module `data` contains serializable values (callers expect JSON-friendly types).
- Verify `Get-LowlyDbaSqlServerAuthSpec` returns an array fragment spec when used with `AnsibleModule.Create()`.
- Confirm `no_log` for password fields in specs.
- Run unit tests for changed helpers and run a sample integration playbook against a local test instance if possible.

Where to look in the codebase

- Module utils: `plugins/module_utils/_SqlServerUtils.psm1`
- Modules: `plugins/modules/*.ps1` (see `agent_job.ps1`, `agent_job_step.ps1` as examples)
- Tests: `tests/integration/targets/*/tasks/main.yml`

If you need to modify behavior:

- Prefer small, well-tested changes to helper functions. Centralized fixes in `module_utils` avoid repeating logic across many modules.
- For path comparisons and idempotency: prefer server-side verification (Get after Set) or minimal normalization, rather than heavy OS-specific path APIs.

Contact

If you need clarification about how a module is expected to behave, read the module's docstring in the Python shim (`plugins/modules/*.py`) and the corresponding integration tests under `tests/integration/targets/*` to see expected inputs/outputs.
