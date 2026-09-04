#Requires -Modules Pester

<#
    .SYNOPSIS
    Pester unit tests for the helper functions in plugins/module_utils/_SqlServerUtils.psm1.

    .DESCRIPTION
    These tests exercise the module_utils helpers directly with mock objects, without
    requiring a live SQL Server connection. Run with:
        Invoke-Pester -Path tests/unit
#>

BeforeAll {
    $script:ModulePath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../../../plugins/module_utils/_SqlServerUtils.psm1')
    Import-Module $script:ModulePath -Force

    # Get-SqlCredential validates that -Module is an instance of Ansible.Basic.AnsibleModule.
    # Rather than pull in the full Ansible runtime, define a minimal test double with the
    # same type name so the ValidateScript type check passes.
    if (-not ('Ansible.Basic.AnsibleModule' -as [type])) {
        Add-Type -TypeDefinition @'
namespace Ansible.Basic
{
    public class AnsibleModule
    {
        public System.Collections.Hashtable Params;
    }
}
'@
    }

    # ConvertTo-SerializableObject special-cases property values whose type name ends in
    # "Collection", or is exactly "User". Define minimal stand-ins for those SMO-like shapes.
    if (-not ('LowlyDbaTests.NameCollection' -as [type])) {
        Add-Type -TypeDefinition @'
namespace LowlyDbaTests
{
    public class NameCollection
    {
        public string[] Name;
    }

    public class User
    {
        public string Name;
    }
}
'@
    }

    function script:New-AnsibleModuleStub {
        param([hashtable]$Params)
        $module = New-Object Ansible.Basic.AnsibleModule
        $module.Params = $Params
        return $module
    }
}

Describe 'Get-LowlyDbaSqlServerAuthSpec' {
    It 'returns the standardized auth option spec' {
        $spec = Get-LowlyDbaSqlServerAuthSpec

        $spec.options.Keys | Should -Contain 'sql_instance'
        $spec.options.sql_instance.required | Should -BeTrue
        $spec.options.sql_username.required | Should -BeFalse
        $spec.options.sql_password.no_log | Should -BeTrue
        $spec.required_together[0] | Should -Be @('sql_username', 'sql_password')
    }
}

Describe 'Get-SqlCredential' {
    It 'returns a null credential when sql_username is not provided' {
        $module = New-AnsibleModuleStub -Params @{ sql_instance = 'localhost'; sql_username = $null; sql_password = $null }

        $result = Get-SqlCredential -Module $module

        $result[0] | Should -Be 'localhost'
        $result[1] | Should -BeNullOrEmpty
    }

    It 'builds a PSCredential when sql_username is provided' {
        $module = New-AnsibleModuleStub -Params @{ sql_instance = 'localhost'; sql_username = 'sa'; sql_password = 'P@ssw0rd!' }

        $result = Get-SqlCredential -Module $module

        $result[0] | Should -Be 'localhost'
        $result[1] | Should -BeOfType [System.Management.Automation.PSCredential]
        $result[1].UserName | Should -Be 'sa'
        $result[1].GetNetworkCredential().Password | Should -Be 'P@ssw0rd!'
    }

    It 'rejects a Module that is not an Ansible.Basic.AnsibleModule' {
        { Get-SqlCredential -Module ([PSCustomObject]@{ Params = @{} }) } | Should -Throw
    }
}

Describe 'ConvertTo-SerializableObject' {
    It 'formats datetime properties as ISO 8601 strings' {
        $now = Get-Date
        $inputObject = [PSCustomObject]@{ CreateDate = $now }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.CreateDate | Should -Be $now.ToString('o')
    }

    It 'stringifies enum properties' {
        $inputObject = [PSCustomObject]@{ Status = [System.DayOfWeek]::Monday }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.Status | Should -Be 'Monday'
    }

    It 'passes through $null properties as $null' {
        $inputObject = [PSCustomObject]@{ Owner = $null }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.Owner | Should -BeNullOrEmpty
    }

    It 'reduces *Collection typed properties to a name array' {
        $jobs = New-Object LowlyDbaTests.NameCollection
        $jobs.Name = @('Job1', 'Job2')
        $inputObject = [PSCustomObject]@{ Jobs = $jobs }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.Jobs | Should -Be @('Job1', 'Job2')
    }

    It 'reduces User typed properties to their name' {
        $owner = New-Object LowlyDbaTests.User
        $owner.Name = 'dbo'
        $inputObject = [PSCustomObject]@{ Owner = $owner }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.Owner | Should -Be 'dbo'
    }

    It 'excludes properties from the default ExcludeProperty list' {
        $inputObject = [PSCustomObject]@{ Name = 'db1'; Urn = 'some/urn/value' }

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.PSObject.Properties.Name | Should -Not -Contain 'Urn'
        $result.Name | Should -Be 'db1'
    }

    It 'honors a custom ExcludeProperty list' {
        $inputObject = [PSCustomObject]@{ Name = 'db1'; Secret = 'hunter2' }

        $result = $inputObject | ConvertTo-SerializableObject -ExcludeProperty @('Secret') -UseDefaultProperty $false

        $result.PSObject.Properties.Name | Should -Not -Contain 'Secret'
        $result.Name | Should -Be 'db1'
    }

    It 'limits output to the default display property set when UseDefaultProperty is true' {
        $inputObject = [PSCustomObject]@{ Name = 'db1'; Size = 100 }
        $propertySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', [string[]]@('Name'))
        $memberSet = [System.Management.Automation.PSMemberSet]::new('PSStandardMembers', [System.Management.Automation.PSMemberInfo[]]@($propertySet))
        $inputObject.PSObject.Members.Add($memberSet)

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $true

        $result.PSObject.Properties.Name | Should -Be @('Name')
    }

    It 'returns all non-excluded properties when UseDefaultProperty is false, even with a default set defined' {
        $inputObject = [PSCustomObject]@{ Name = 'db1'; Size = 100 }
        $propertySet = [System.Management.Automation.PSPropertySet]::new('DefaultDisplayPropertySet', [string[]]@('Name'))
        $memberSet = [System.Management.Automation.PSMemberSet]::new('PSStandardMembers', [System.Management.Automation.PSMemberInfo[]]@($propertySet))
        $inputObject.PSObject.Members.Add($memberSet)

        $result = $inputObject | ConvertTo-SerializableObject -UseDefaultProperty $false

        $result.PSObject.Properties.Name | Should -Contain 'Name'
        $result.PSObject.Properties.Name | Should -Contain 'Size'
    }
}
