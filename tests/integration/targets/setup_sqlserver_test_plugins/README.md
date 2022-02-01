# What is this?

This collection contains a connection plugin and a shell plugin, with the goal of running Ansible PowerShell modules (traditionally only able to be run on remote Windows hosts), directly on the Ansible controller via `pwsh`, without modifications to the modules.

## Supportability

This is extremely experimental, and relies at least in part, on some hackery. Use with caution.

The goal of not modifying modules to run this way _should_ support the notion that if this hackery fails, the module could instead be run against a remote Windows host as a sort of proxy, as long as the module already does its work against a remote system (like modules intended to manage SQL servers).
