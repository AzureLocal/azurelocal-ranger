function Invoke-RangerModuleValidation {
    <#
    .SYNOPSIS
        v2.0.0 (#231): validate and optionally install/update required PowerShell
        modules on startup.
    .DESCRIPTION
        Iterates a list of required and optional modules, checks installed
        version via Get-Module -ListAvailable, and attempts Install-Module /
        Update-Module when below the minimum. Failures log a warning but do
        not abort the run. Skipped entirely when -SkipModuleUpdate is set on
        the outer command.
    #>
    [CmdletBinding()]
    param(
        [switch]$Quiet
    )

    $required = @(
        @{ Name = 'Az.Accounts';        MinVersion = '2.13.0' },
        @{ Name = 'Az.Resources';       MinVersion = '6.0.0'  },
        @{ Name = 'Az.ConnectedMachine';MinVersion = '0.7.0'  },
        @{ Name = 'Az.KeyVault';        MinVersion = '4.0.0'  }
    )
    $optional = @(
        @{ Name = 'Az.StackHCI';        MinVersion = '2.0.0';   Reason = 'HCI cluster-level operations' },
        @{ Name = 'Az.ResourceGraph';   MinVersion = '0.13.0';  Reason = 'Faster ARM discovery (#205)' },
        @{ Name = 'ImportExcel';        MinVersion = '7.8.0';   Reason = 'XLSX output (#209)' }
    )

    $results = New-Object System.Collections.ArrayList

    foreach ($m in $required) {
        $result = Invoke-RangerSingleModuleCheck -Name $m.Name -MinVersion $m.MinVersion -Category 'required' -Quiet:$Quiet
        [void]$results.Add($result)
    }
    foreach ($m in $optional) {
        $result = Invoke-RangerSingleModuleCheck -Name $m.Name -MinVersion $m.MinVersion -Category 'optional' -Reason $m.Reason -Quiet:$Quiet
        [void]$results.Add($result)
    }

    return @($results)
}

function Invoke-RangerSingleModuleCheck {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$MinVersion,
        [Parameter(Mandatory = $true)][ValidateSet('required','optional')][string]$Category,
        [string]$Reason,
        [switch]$Quiet
    )

    $available = @(Get-Module -ListAvailable -Name $Name -ErrorAction SilentlyContinue)
    $installedMax = if ($available.Count -gt 0) {
        ($available | Sort-Object Version -Descending | Select-Object -First 1).Version
    } else { $null }

    $minVer = [version]$MinVersion
    $action = 'none'
    $status = 'ok'
    $message = $null

    if (-not $installedMax) {
        if ($Category -eq 'required') {
            $action = 'install'
            $message = "Installing $Name (>= $MinVersion)..."
            try {
                if (-not $Quiet) { Write-Host "[ranger] $message" -ForegroundColor DarkCyan }
                Install-Module -Name $Name -MinimumVersion $MinVersion -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
                $status = 'installed'
            } catch {
                Write-Warning "Module install failed: $Name — $($_.Exception.Message). Continuing; run will be affected if $Name is needed."
                $status = 'install-failed'
            }
        } else {
            $status = 'missing-optional'
            $message = "Optional module '$Name' not installed ($Reason). Install with: Install-Module $Name -Scope CurrentUser"
            if (-not $Quiet) { Write-Verbose $message }
        }
    } elseif ($installedMax -lt $minVer) {
        $action = 'update'
        $message = "Updating $Name ($installedMax → >= $MinVersion)..."
        try {
            if (-not $Quiet) { Write-Host "[ranger] $message" -ForegroundColor DarkCyan }
            Update-Module -Name $Name -Force -ErrorAction Stop
            $status = 'updated'
        } catch {
            Write-Warning "Module update failed: $Name — $($_.Exception.Message). Installed $installedMax remains in use."
            $status = 'update-failed'
        }
    } else {
        $status = 'current'
    }

    [ordered]@{
        name           = $Name
        category       = $Category
        minVersion     = $MinVersion
        installedMax   = if ($installedMax) { [string]$installedMax } else { $null }
        action         = $action
        status         = $status
        message        = $message
    }
}
