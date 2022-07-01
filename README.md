# lowlydba.sqlserver Collection for Ansible

![GPL v3](https://img.shields.io/github/license/lowlydba/lowlydba.sqlserver)
[![CI](https://github.com/lowlydba/lowlydba.sqlserver/actions/workflows/ansible-test.yml/badge.svg)](https://github.com/lowlydba/lowlydba.sqlserver/actions/workflows/ansible-test.yml)
[![CI (Windows)](https://github.com/lowlydba/lowlydba.sqlserver/actions/workflows/ansible-test-windows.yml/badge.svg)](https://github.com/lowlydba/lowlydba.sqlserver/actions/workflows/ansible-test-windows.yml)
[![codecov](https://codecov.io/gh/lowlydba/lowlydba.sqlserver/branch/main/graph/badge.svg?token=3TW3VBCn9N)](https://codecov.io/gh/lowlydba/lowlydba.sqlserver)

- [Modules](#modules)
- [Code of Conduct](#code-of-conduct)
- [Communication](#communication)
- [Contributing to this collection](#contributing-to-this-collection)
- [Collection maintenance](#collection-maintenance)
- [Tested with](#tested-with)
- [External requirements](#external-requirements)
- [Using this collection](#using-this-collection)
  - [Installing the Collection from Ansible Galaxy](#installing-the-collection-from-ansible-galaxy)
- [Release notes](#release-notes)
- [Roadmap](#roadmap)

## Modules

See the [plugin section](https://lowlydba.github.io/lowlydba.sqlserver/branch/main/collections/lowlydba/sqlserver/index.html#plugins-in-lowlydba-sqlserver) of the documentation for this collection (<https://lowlydba.github.io/lowlydba.sqlserver>).

## Code of Conduct

We follow the [Ansible Code of Conduct](https://docs.ansible.com/ansible/devel/community/code_of_conduct.html) in all our interactions within this project.

If you encounter abusive behavior, please refer to the [policy violations](https://docs.ansible.com/ansible/devel/community/code_of_conduct.html#policy-violations) section of the Code for information on how to raise a complaint.

## Communication

We announce releases and important changes through Ansible's [The Bullhorn newsletter](https://github.com/ansible/community/wiki/News#the-bullhorn). Be sure you are [subscribed](https://eepurl.com/gZmiEP).

Join us in the `#ansible` (general use questions and support), `#ansible-community` (community and collection development questions), and other [IRC channels](https://docs.ansible.com/ansible/devel/community/communication.html#irc-channels).

We take part in the global quarterly [Ansible Contributor Summit](https://github.com/ansible/community/wiki/Contributor-Summit) virtually or in-person. Track [The Bullhorn newsletter](https://eepurl.com/gZmiEP) and join us.

For more information about communication, refer to the [Ansible Communication guide](https://docs.ansible.com/ansible/devel/community/communication.html).

## Contributing to this collection

The content of this collection is made by people like you, a community of individuals collaborating on making the world better through developing automation software. We are actively accepting new contributors.

We use the following guidelines:

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [REVIEW_CHECKLIST.md](REVIEW_CHECKLIST.md)
- [Ansible Community Guide](https://docs.ansible.com/ansible/latest/community/index.html)
- [Ansible Development Guide](https://docs.ansible.com/ansible/devel/dev_guide/index.html)
- [Ansible Collection Development Guide](https://docs.ansible.com/ansible/devel/dev_guide/developing_collections.html#contributing-to-collections)

## Collection maintenance

The current maintainers are listed in the [MAINTAINERS](MAINTAINERS) file. If you have questions or need help, feel free to mention them in the proposals.

To learn how to maintain / become a maintainer of this collection, refer to the [Maintainer guidelines](MAINTAINING.md).

## Tested with

### Ansible

- 2.11
- 2.12
- 2.13
- dlevel

### SQL Server

- SQL Server 2000 - current (via DBATools)

## External requirements

- PowerShell modules
  - [dbatools][dbatools] >= 1.1.108
  - [dbops][dbops] >= 0.8.0

## Using this collection

### Installing the Collection from Ansible Galaxy

Before using this collection, you need to install it with the Ansible Galaxy command-line tool:

```bash
ansible-galaxy collection install lowlydba.sqlserver
```

You can also include it in a `requirements.yml` file and install it with `ansible-galaxy collection install -r requirements.yml`, using the format:

```yaml
---
collections:
  - name: lowlydba.sqlserver
```

Note that if you install the collection from Ansible Galaxy, it will not be upgraded automatically when you upgrade the `ansible` package. To upgrade the collection to the latest available version, run the following command:

```bash
ansible-galaxy collection install lowlydba.sqlserver --upgrade
```

You can also install a specific version of the collection, for example, if you need to downgrade when something is broken in the latest version (please report an issue in this repository). Use the following syntax to install version `0.1.0`:

```bash
ansible-galaxy collection install lowlydba.sqlserver:==0.1.0
```

See [Ansible Using collections](https://docs.ansible.com/ansible/devel/user_guide/collections_using.html) for more details.

## Release notes

See the [changelog](https://github.com/lowlydba/lowlydba.sqlserver/tree/main/CHANGELOG.rst).

## Roadmap

TBD

<!-- Link shortcuts -->
[dbatools]: https://dbatools.io
[dbops]: https://github.com/dataplat/dbops
