function Invoke-RangerNetworkDeviceConfigImport {
    <#
    .SYNOPSIS
        Imports offline vendor config files specified in the networkDeviceConfigs hints section.
    .DESCRIPTION
        Processes config files for switches and firewalls that are listed under
        $Config.domains.hints.networkDeviceConfigs. Returns arrays for switchConfig and
        firewallConfig networking domain keys.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config
    )

    $hints = $Config.domains.hints
    $deviceConfigHints = @($hints.networkDeviceConfigs)

    $switchConfigs  = New-Object System.Collections.ArrayList
    $firewallConfigs = New-Object System.Collections.ArrayList

    if ($deviceConfigHints.Count -eq 0) {
        return [ordered]@{
            switchConfig   = @()
            firewallConfig = @()
        }
    }

    foreach ($hint in $deviceConfigHints) {
        if ($null -eq $hint) {
            continue
        }

        $path   = $hint.path
        $vendor = $hint.vendor
        $role   = $hint.role

        if (-not $path) {
            Write-RangerLog -Level warn -Message "networkDeviceConfigs hint is missing a 'path' field — skipping entry."
            continue
        }

        $resolvedPath = Resolve-RangerPath -Path $path
        if (-not (Test-Path -Path $resolvedPath)) {
            Write-RangerLog -Level warn -Message "networkDeviceConfigs: file not found at '$resolvedPath' — skipping."
            continue
        }

        $rawContent = Get-Content -Path $resolvedPath -Raw -ErrorAction Stop
        $normalizedVendor = ($vendor ?? 'unknown').ToLowerInvariant()

        $parsed = switch -Wildcard ($normalizedVendor) {
            'cisco-nxos'  { ConvertFrom-RangerCiscoNxosConfig -RawContent $rawContent -FilePath $resolvedPath -Role $role }
            'cisco-ios'   { ConvertFrom-RangerCiscoIosConfig  -RawContent $rawContent -FilePath $resolvedPath -Role $role }
            default {
                Write-RangerLog -Level warn -Message "networkDeviceConfigs: vendor '$vendor' is not supported — recording file reference only."
                [ordered]@{
                    sourceFile = [System.IO.Path]::GetFileName($resolvedPath)
                    vendor     = $vendor
                    role       = $role
                    parseStatus = 'unsupported-vendor'
                    vlans       = @()
                    portChannels = @()
                    interfaces  = @()
                    acls        = @()
                }
            }
        }

        if ($role -eq 'firewall') {
            [void]$firewallConfigs.Add($parsed)
        }
        else {
            [void]$switchConfigs.Add($parsed)
        }
    }

    return [ordered]@{
        switchConfig   = @($switchConfigs)
        firewallConfig = @($firewallConfigs)
    }
}

function ConvertFrom-RangerCiscoNxosConfig {
    <#
    .SYNOPSIS
        Parses a Cisco NX-OS show running-config text dump.
    .OUTPUTS
        Ordered hashtable with vlans, portChannels, interfaces, and acls.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawContent,

        [string]$FilePath,
        [string]$Role
    )

    $lines = $RawContent -split '\r?\n'

    $vlans        = New-Object System.Collections.ArrayList
    $portChannels = New-Object System.Collections.ArrayList
    $interfaces   = New-Object System.Collections.ArrayList
    $acls         = New-Object System.Collections.ArrayList

    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i].Trim()

        # VLAN database entries: "vlan <id>" or "vlan <id>,<id>-<id>"
        if ($line -match '^vlan\s+([\d,\-]+)$') {
            $vlanRange = $Matches[1]
            $vlanIds = Expand-RangerVlanRange -Range $vlanRange
            $vlanName = $null
            $vlanState = $null

            # Look ahead for name and state lines within the same vlan block
            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -match '^\s+') {
                $inner = $lines[$j].Trim()
                if ($inner -match '^name\s+(.+)$') { $vlanName = $Matches[1] }
                if ($inner -match '^state\s+(\S+)$') { $vlanState = $Matches[1] }
                $j++
            }

            foreach ($id in $vlanIds) {
                [void]$vlans.Add([ordered]@{
                    vlanId = $id
                    name   = $vlanName
                    state  = $vlanState ?? 'active'
                })
            }
            $i = $j
            continue
        }

        # Port-channel / LAG interfaces
        if ($line -match '^interface\s+(port-channel\d+)$') {
            $pcName = $Matches[1]
            $pcDesc = $null
            $pcMembers = @()
            $pcMode = $null
            $allowedVlans = $null

            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -match '^\s+') {
                $inner = $lines[$j].Trim()
                if ($inner -match '^description\s+(.+)$') { $pcDesc = $Matches[1] }
                if ($inner -match '^switchport mode\s+(\S+)$') { $pcMode = $Matches[1] }
                if ($inner -match '^switchport trunk allowed vlan\s+(.+)$') { $allowedVlans = $Matches[1] }
                $j++
            }

            [void]$portChannels.Add([ordered]@{
                name         = $pcName
                description  = $pcDesc
                mode         = $pcMode
                allowedVlans = $allowedVlans
            })
            $i = $j
            continue
        }

        # All other interfaces (Ethernet, mgmt, etc.)
        if ($line -match '^interface\s+(Ethernet\S+|mgmt\S+|Vlan\d+)$') {
            $ifName = $Matches[1]
            $ifDesc = $null
            $ifMode = $null
            $ifVlan = $null
            $ifTrunkVlans = $null
            $ifChannel = $null
            $ifShutdown = $false

            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -match '^\s+') {
                $inner = $lines[$j].Trim()
                if ($inner -match '^description\s+(.+)$') { $ifDesc = $Matches[1] }
                if ($inner -match '^switchport mode\s+(\S+)$') { $ifMode = $Matches[1] }
                if ($inner -match '^switchport access vlan\s+(\d+)$') { $ifVlan = [int]$Matches[1] }
                if ($inner -match '^switchport trunk allowed vlan\s+(.+)$') { $ifTrunkVlans = $Matches[1] }
                if ($inner -match '^channel-group\s+(\d+)') { $ifChannel = "port-channel$($Matches[1])" }
                if ($inner -eq 'shutdown') { $ifShutdown = $true }
                $j++
            }

            [void]$interfaces.Add([ordered]@{
                name        = $ifName
                description = $ifDesc
                mode        = $ifMode
                accessVlan  = $ifVlan
                trunkVlans  = $ifTrunkVlans
                portChannel = $ifChannel
                shutdown    = $ifShutdown
            })
            $i = $j
            continue
        }

        # IP access-lists (ACLs)
        if ($line -match '^ip access-list\s+(\S+)$') {
            $aclName = $Matches[1]
            $aclEntries = New-Object System.Collections.ArrayList

            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -match '^\s+') {
                $inner = $lines[$j].Trim()
                if ($inner -match '^\d+\s+(.+)$' -or $inner -match '^(permit|deny)\s+.+$') {
                    [void]$aclEntries.Add($inner)
                }
                $j++
            }

            [void]$acls.Add([ordered]@{
                name    = $aclName
                entries = @($aclEntries)
            })
            $i = $j
            continue
        }

        $i++
    }

    return [ordered]@{
        sourceFile   = [System.IO.Path]::GetFileName($FilePath)
        vendor       = 'cisco-nxos'
        role         = $Role
        parseStatus  = 'parsed'
        vlans        = @($vlans)
        portChannels = @($portChannels)
        interfaces   = @($interfaces)
        acls         = @($acls)
    }
}

function ConvertFrom-RangerCiscoIosConfig {
    <#
    .SYNOPSIS
        Parses a Cisco IOS show running-config text dump.
    .OUTPUTS
        Ordered hashtable with vlans, portChannels, interfaces, and acls.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RawContent,

        [string]$FilePath,
        [string]$Role
    )

    # IOS syntax is close enough to NX-OS for the keys we care about. Parse as NX-OS
    # and override vendor label in the output.
    $result = ConvertFrom-RangerCiscoNxosConfig -RawContent $RawContent -FilePath $FilePath -Role $Role

    # override vendor label only — IOS has vlan database blocks starting with "vlan database"
    # which are already skipped by the NX-OS parser harmlessly.
    $result['vendor'] = 'cisco-ios'
    return $result
}

function Expand-RangerVlanRange {
    <#
    .SYNOPSIS
        Expands a VLAN range string such as "10,20-25,30" into an array of integer VLAN IDs.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Range
    )

    $ids = New-Object System.Collections.Generic.List[int]
    foreach ($segment in ($Range -split ',')) {
        $segment = $segment.Trim()
        if ($segment -match '^(\d+)-(\d+)$') {
            for ($n = [int]$Matches[1]; $n -le [int]$Matches[2]; $n++) {
                $ids.Add($n)
            }
        }
        elseif ($segment -match '^\d+$') {
            $ids.Add([int]$segment)
        }
    }
    return @($ids)
}
