#!powershell
# -*- coding: utf-8 -*-

# (c) 2022, John McCall (@lowlydba)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.lowlydba.sqlserver.plugins.module_utils._SqlServerUtils
#Requires -Modules @{ ModuleName="dbatools"; ModuleVersion="2.0.0" }

$ErrorActionPreference = "Stop"

$spec = @{
    supports_check_mode = $true
    options = @{
        ag_name = @{type = 'str'; required = $true }
        listener_name = @{type = 'str'; required = $true }
        ip_address = @{type = 'list'; elements = 'str'; required = $false }
        subnet_ip = @{type = 'list'; elements = 'str'; required = $false }
        subnet_mask = @{type = 'list'; elements = 'str'; required = $false; default = '255.255.255.0' }
        port = @{type = 'int'; required = $false; default = 1433 }
        dhcp = @{type = 'bool'; required = $false; default = $false }
        state = @{type = "str"; required = $false; default = "present"; choices = @("present", "absent") }
    }
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-LowlyDbaSqlServerAuthSpec))
$sqlInstance, $sqlCredential = Get-SqlCredential -Module $module
$agName = $module.Params.ag_name
$listenerName = $module.Params.listener_name
$subnetIp = $module.Params.subnet_ip
$subnetMask = $module.Params.subnet_mask
$ipAddress = $module.Params.ip_address
$port = $module.Params.port
$dhcp = $module.Params.dhcp
$state = $module.Params.state
$checkMode = $module.CheckMode
$module.Result.changed = $false
$PSDefaultParameterValues = @{
    "*:SqlInstance" = $sqlInstance
    "*:SqlCredential" = $sqlCredential
    "*:EnableException" = $true
    "*:Confirm" = $false
    "*:WhatIf" = $checkMode
}

function Get-DesiredListenerIp {
    <#
        .SYNOPSIS
        Normalizes the desired IP configuration for a listener based on module params.

        .DESCRIPTION
        Mirrors the IP/SubnetMask pairing logic used by Add-DbaAgListener so the desired
        state can be compared against what already exists on the server.
    #>
    param(
        [AllowNull()][string[]]$IpAddress,
        [AllowNull()][string[]]$SubnetMask,
        [bool]$Dhcp
    )
    if ($Dhcp) {
        return , [PSCustomObject]@{ IsDhcp = $true; IPAddress = $null; SubnetMask = $null }
    }
    if ($null -eq $IpAddress) {
        return @()
    }
    $masks = $SubnetMask
    if ($null -eq $masks -or $masks.Count -eq 0) {
        $masks = , '255.255.255.0'
    }
    if ($masks.Count -eq 1 -and $IpAddress.Count -gt 1) {
        $masks = @($masks[0]) * $IpAddress.Count
    }
    $desired = @()
    for ($i = 0; $i -lt $IpAddress.Count; $i++) {
        $desired += [PSCustomObject]@{
            IsDhcp = $false
            IPAddress = [string]$IpAddress[$i]
            SubnetMask = [string]$masks[$i]
        }
    }
    return $desired
}

function Test-ListenerIpMismatch {
    <#
        .SYNOPSIS
        Compares the listener's current IP configuration against the desired state.

        .DESCRIPTION
        Returns $true when the existing listener's IP addresses/subnet masks/DHCP
        setting differ from the desired configuration. Listener IPs can't be altered
        in place, so a mismatch means the listener must be dropped and re-created.
    #>
    param(
        $ExistingListener,
        [array]$DesiredIps
    )
    if ($DesiredIps.Count -eq 0) {
        # Caller did not request management of IP/DHCP settings, leave as-is.
        return $false
    }
    $existingIps = @($ExistingListener.AvailabilityGroupListenerIPAddresses | ForEach-Object {
        if ($_.IsDHCP) {
            [PSCustomObject]@{ IsDhcp = $true; IPAddress = $null; SubnetMask = $null }
        }
        else {
            [PSCustomObject]@{ IsDhcp = $false; IPAddress = [string]$_.IPAddress; SubnetMask = [string]$_.SubnetMask }
        }
    })
    if ($existingIps.Count -ne $DesiredIps.Count) {
        return $true
    }
    if ($DesiredIps[0].IsDhcp) {
        return -not ($existingIps | Where-Object { $_.IsDhcp })
    }
    if ($existingIps | Where-Object { $_.IsDhcp }) {
        return $true
    }
    $existingSet = @($existingIps | ForEach-Object { "$($_.IPAddress)|$($_.SubnetMask)" } | Sort-Object)
    $desiredSet = @($DesiredIps | ForEach-Object { "$($_.IPAddress)|$($_.SubnetMask)" } | Sort-Object)
    return [bool](Compare-Object -ReferenceObject $existingSet -DifferenceObject $desiredSet)
}

try {
    $existingListener = Get-DbaAgListener -AvailabilityGroup $agName -Listener $listenerName
    if ($state -eq "present") {
        $listenerParams = @{
            AvailabilityGroup = $agName
            Name = $listenerName
            Port = $port
            Dhcp = $dhcp
            SubnetMask = $subnetMask
        }
        if ($null -ne $ipAddress) {
            $listenerParams.Add("IPAddress", $ipAddress)
        }
        if ($null -ne $subnetIp) {
            $listenerParams.Add("SubnetIP", $subnetIp)
        }
        if ($null -eq $existingListener) {
            $output = Add-DbaAgListener @listenerParams
            $module.Result.changed = $true
        }
        else {
            $desiredIps = Get-DesiredListenerIp -IpAddress $ipAddress -SubnetMask $subnetMask -Dhcp $dhcp
            if (Test-ListenerIpMismatch -ExistingListener $existingListener -DesiredIps $desiredIps) {
                # IP addresses/DHCP cannot be altered in place, drop and re-create the listener.
                $null = Remove-DbaAgListener -AvailabilityGroup $agName -Listener $listenerName
                $output = Add-DbaAgListener @listenerParams
                $module.Result.changed = $true
            }
            elseif ($existingListener.PortNumber -ne $port) {
                $output = Set-DbaAgListener -AvailabilityGroup $agName -Listener $listenerName -Port $port
                $module.Result.changed = $true
            }
        }
    }
    elseif ($state -eq "absent") {
        if ($null -ne $existingListener) {
            $output = Remove-DbaAgListener -AvailabilityGroup $agName -Listener $listenerName
            $module.Result.changed = $true
        }
    }

    if ($output) {
        $resultData = ConvertTo-SerializableObject -InputObject $output
        $module.Result.data = $resultData
    }
    $module.ExitJson()
}
catch {
    $module.FailJson("Configuring availability group listener failed: $($_.Exception.Message)", $_)
}
