BeforeAll {
    $script:repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..\..') | Select-Object -ExpandProperty Path
    $script:fixtureRoot = Join-Path $script:repoRoot 'tests\maproom\Fixtures'
    Import-Module (Join-Path $script:repoRoot 'AzureLocalRanger.psd1') -Force

    # Collect every identifier that must not survive, straight from the fixture manifest.
    function script:Get-OriginalIdentifiers {
        param($Manifest)
        $ids = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        $json = $Manifest | ConvertTo-Json -Depth 100
        foreach ($m in [regex]::Matches($json, '\b(?:(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\.){3}(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)\b')) {
            if ($m.Value -notmatch '^(?:0\.0\.0\.0|127\.|255\.|169\.254\.)') { [void]$ids.Add($m.Value) }
        }
        foreach ($m in [regex]::Matches($json, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')) { [void]$ids.Add($m.Value) }
        foreach ($m in [regex]::Matches($json, '\b[a-z0-9][a-z0-9-]*(?:\.[a-z0-9-]+)*\.(?:local|lan|corp)\b', 'IgnoreCase')) { [void]$ids.Add($m.Value) }
        $walk = {
            param($o, $parent)
            if ($o -is [System.Collections.IDictionary]) {
                foreach ($k in $o.Keys) {
                    $v = $o[$k]
                    if ($v -is [string] -and $v.Length -ge 5) {
                        if ($k -match '(?i)^(serialNumber|serviceTag|resourceGroup|resourceGroupName|clusterName|node|hostNode|ownerNode|macAddress)$') { [void]$ids.Add($v) }
                        if ($k -eq 'name' -and $parent -match '^(?i)nodes$') { [void]$ids.Add($v) }
                    }
                    & $walk $v $k
                }
            }
            elseif ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) { foreach ($e in $o) { & $walk $e $parent } }
        }
        & $walk $Manifest ''
        # Short and structural values are not identifiers by themselves.
        return @($ids | Where-Object { $_.Length -ge 5 -and $_ -notmatch '^(?:Mirror|Rack|Server|Windows)' })
    }

    function script:Get-ArtifactText {
        # Returns the searchable text of one generated file: plain text, or every XML part of an OOXML zip, or raw PDF bytes.
        param([string]$Path)
        $ext = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        if ($ext -in '.docx', '.xlsx', '.pptx') {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($Path)
            try {
                $sb = [System.Text.StringBuilder]::new()
                foreach ($e in $zip.Entries) {
                    $r = [System.IO.StreamReader]::new($e.Open())
                    try { [void]$sb.AppendLine($r.ReadToEnd()) } finally { $r.Dispose() }
                }
                return $sb.ToString()
            }
            finally { $zip.Dispose() }
        }
        if ($ext -eq '.pdf') { return [System.Text.Encoding]::Latin1.GetString([System.IO.File]::ReadAllBytes($Path)) }
        return [System.IO.File]::ReadAllText($Path)
    }
}

Describe 'Redaction pseudonymiser' {
    BeforeEach {
        $script:ctx = & (Get-Module AzureLocalRanger) { New-RangerRedactionContext -Seed 'pester-seed' }
    }

    It 'maps the same value to the same pseudonym and never returns the original' {
        $a = & (Get-Module AzureLocalRanger) { param($c) Get-RangerPseudonym -Context $c -Value '10.20.30.40' -Kind ipv4 } $script:ctx
        $b = & (Get-Module AzureLocalRanger) { param($c) Get-RangerPseudonym -Context $c -Value '10.20.30.40' -Kind ipv4 } $script:ctx
        $a | Should -Be $b
        $a | Should -Not -Be '10.20.30.40'
        $a | Should -Match '^192\.0\.2\.\d+$'
    }

    It 'redacts IPv4, IPv6, MAC (three styles), GUID, UPN, FQDN, host, serial and resource group in free text and is idempotent' {
        $text = 'node azl-n01 (azl-n01.corp.example-lab.local) 10.20.30.40/24 2001:4860:4860::8888 aa:bb:cc:dd:ee:ff AA-BB-CC-DD-EE-FF aabb.ccdd.eeff 550e8400-e29b-41d4-a716-446655440000 alice@corp.example-lab.local ABC1234 /subscriptions/550e8400-e29b-41d4-a716-446655440000/resourceGroups/rg-prod-azl-01/providers/x'
        $r = & (Get-Module AzureLocalRanger) {
            param($c, $t)
            Add-RangerRedactionLiteral -Context $c -Value 'azl-n01.corp.example-lab.local' -Kind fqdn
            Add-RangerRedactionLiteral -Context $c -Value 'ABC1234' -Kind serial
            $once = Protect-RangerText -Context $c -Text $t
            [pscustomobject]@{ Once = $once; Twice = (Protect-RangerText -Context $c -Text $once) }
        } $script:ctx $text
        foreach ($original in 'azl-n01', 'corp.example-lab.local', '10.20.30.40', '2001:4860:4860::8888', 'aa:bb:cc:dd:ee:ff', 'AA-BB-CC-DD-EE-FF', 'aabb.ccdd.eeff', '550e8400-e29b-41d4-a716-446655440000', 'alice', 'ABC1234', 'rg-prod-azl-01') {
            $r.Once | Should -Not -Match ([regex]::Escape($original))
        }
        $r.Once | Should -Match '/24'
        $r.Twice | Should -BeExactly $r.Once
    }

    It 'leaves masks, loopback, link-local and public Microsoft names alone' {
        $text = 'mask 255.255.255.0 any 0.0.0.0 lo 127.0.0.1 ::1 https://management.azure.com/ https://learn.microsoft.com/azure/azure-local/ Microsoft.AzureStackHCI 10.0.25398.1 report.md'
        $r = & (Get-Module AzureLocalRanger) { param($c, $t) Protect-RangerText -Context $c -Text $t } $script:ctx $text
        $r | Should -BeExactly $text
    }

    It 'removes SAS signatures, SNMP communities, down-level accounts, APIPA and link-local addresses' {
        $text = 'https://x.example.test/c?sv=2023-11-03&sig=Qm9ndXNTaWduYXR1cmU%3D and snmp-server community BranchMonitoringRO ro by FABRIKAM\jpatel apipa 169.254.42.17 ll fe80::a12b:34ff:fe56:7890 password=Hunter2!x cert CN=idrac07.fabrikam,O=Fabrikam Manufacturing'
        $r = & (Get-Module AzureLocalRanger) { param($c, $t) Protect-RangerText -Context $c -Text $t } $script:ctx $text
        foreach ($secret in 'Qm9ndXNTaWduYXR1cmU', 'BranchMonitoringRO', 'jpatel', 'FABRIKAM', '169.254.42.17', 'a12b:34ff', 'Hunter2', 'Fabrikam Manufacturing', 'idrac07') {
            $r | Should -Not -Match ([regex]::Escape($secret))
        }
        $r | Should -Match 'NT AUTHORITY|snmp-server community'
    }

    It 'leaves built-in down-level authorities readable' {
        $r = & (Get-Module AzureLocalRanger) { param($c) Protect-RangerText -Context $c -Text 'NT AUTHORITY\SYSTEM BUILTIN\Administrators root\cimv2 C:\Windows\System32' } $script:ctx
        $r | Should -BeExactly 'NT AUTHORITY\SYSTEM BUILTIN\Administrators root\cimv2 C:\Windows\System32'
    }

    It 'hides storage account and key vault names but keeps the service suffix' {
        $r = & (Get-Module AzureLocalRanger) { param($c) Protect-RangerText -Context $c -Text 'https://stwitnessprod01.blob.core.windows.net/c and kv-secret-01.vault.azure.net' } $script:ctx
        $r | Should -Not -Match 'stwitnessprod01|kv-secret-01'
        $r | Should -Match '\.blob\.core\.windows\.net'
        $r | Should -Match '\.vault\.azure\.net'
    }

    It 'replaces operator terms inside longer names' {
        $r = & (Get-Module AzureLocalRanger) {
            param($c)
            Add-RangerRedactionTerm -Context $c -Term 'acmecorp'
            Protect-RangerText -Context $c -Text 'csv-acmecorp-vmstore-01 AcmeCorp'
        } $script:ctx
        $r | Should -Not -Match '(?i)acmecorp'
    }

    It 'writes a map only when asked and the map reverses the pseudonyms' {
        $path = Join-Path $TestDrive 'private-map.json'
        & (Get-Module AzureLocalRanger) {
            param($c, $p)
            $null = Protect-RangerText -Context $c -Text '10.1.2.3'
            Write-RangerRedactionMap -Context $c -Path $p
        } $script:ctx $path | Out-Null
        $map = Get-Content $path -Raw | ConvertFrom-Json
        @($map.entries | Where-Object { $_.original -eq '10.1.2.3' }).Count | Should -Be 1
        $map.warning | Should -Match 'private'
    }

    It 'does not mutate the input manifest' {
        $m = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $before = $m | ConvertTo-Json -Depth 100
        $null = & (Get-Module AzureLocalRanger) { param($m, $c) ConvertTo-RangerRedactedManifest -Manifest $m -Context $c } $m $script:ctx
        ($m | ConvertTo-Json -Depth 100) | Should -BeExactly $before
    }
}

Describe 'Redaction across every output format' {
    BeforeAll {
        $script:manifestPath = Join-Path $script:fixtureRoot 'synthetic-manifest.json'
        $script:original = Get-Content $script:manifestPath -Raw | ConvertFrom-Json -AsHashtable
        $script:identifiers = script:Get-OriginalIdentifiers -Manifest $script:original
        $script:outRoot = Join-Path $TestDrive 'redacted-package'
        $script:mapPath = Join-Path $TestDrive 'private-map.json'
        Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath $script:outRoot `
            -Formats @('html', 'markdown', 'svg', 'drawio', 'docx', 'xlsx', 'pdf', 'powerbi', 'pptx', 'json-evidence') `
            -Redact -RedactMapPath $script:mapPath -RedactTerm 'iic' | Out-Null
        $script:files = @(Get-ChildItem -Path $script:outRoot -Recurse -File)
    }

    It 'found a meaningful set of original identifiers to look for' {
        $script:identifiers.Count | Should -BeGreaterThan 20
    }

    It 'produced every requested format plus the redacted manifest' {
        foreach ($ext in '.html', '.md', '.svg', '.drawio', '.docx', '.xlsx', '.pdf', '.pptx', '.json', '.csv') {
            @($script:files | Where-Object { $_.Extension -eq $ext }).Count | Should -BeGreaterThan 0 -Because "a $ext artifact is expected"
        }
        Test-Path (Join-Path $script:outRoot 'manifest\audit-manifest.redacted.json') | Should -BeTrue
    }

    It 'leaves no original identifier in any generated artifact (text, OOXML parts, PDF) or file name' {
        $leaks = New-Object System.Collections.Generic.List[string]
        foreach ($file in $script:files) {
            $text = script:Get-ArtifactText -Path $file.FullName
            foreach ($id in $script:identifiers) {
                $pattern = '(?<![A-Za-z0-9])' + [regex]::Escape($id) + '(?![A-Za-z0-9])'
                if ([regex]::IsMatch($text, $pattern, 'IgnoreCase')) { $leaks.Add("$($file.Name): $id") }
                if ([regex]::IsMatch($file.Name, $pattern, 'IgnoreCase')) { $leaks.Add("filename $($file.Name): $id") }
            }
            if ($text -match '(?i)\biic\b') { $leaks.Add("$($file.Name): term iic") }
        }
        $leaks | Should -BeNullOrEmpty
    }

    It 'wrote the private map only because -RedactMapPath was supplied, outside the shared package' {
        Test-Path $script:mapPath | Should -BeTrue
        @($script:files | Where-Object { $_.FullName -eq (Resolve-Path $script:mapPath).Path -or ($_.Extension -eq '.json' -and (Get-Content $_.FullName -Raw) -match 'reverses the redaction') }).Count | Should -Be 0
        (Get-Content $script:mapPath -Raw | ConvertFrom-Json).entries.Count | Should -BeGreaterThan 20
    }

    It 'does not write a map when -RedactMapPath is absent' {
        $out = Join-Path $TestDrive 'no-map'
        Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath $out -Formats @('markdown') -Redact | Out-Null
        @(Get-ChildItem $out -Recurse -File -Filter *.json | Where-Object { (Get-Content $_.FullName -Raw) -match 'reverses the redaction' }).Count | Should -Be 0
    }

    It 'refuses to redact on top of the source package' {
        { Export-AzureLocalRangerReport -ManifestPath $script:manifestPath -OutputPath (Split-Path -Parent $script:manifestPath) -Formats @('markdown') -Redact } | Should -Throw '*must differ*'
    }

    It 'keeps the manifest structure intact (same domains, counts preserved)' {
        $red = Get-Content (Join-Path $script:outRoot 'manifest\audit-manifest.redacted.json') -Raw | ConvertFrom-Json -AsHashtable
        @($red.domains.clusterNode.nodes).Count | Should -Be @($script:original.domains.clusterNode.nodes).Count
        $red.run.redaction.enabled | Should -BeTrue
        $red.run.redaction.PSObject.Properties.Name -contains 'map' | Should -BeFalse
    }
}

Describe 'Redaction in the discovery run and Publish-RangerRun' {
    It 'Publish-RangerRun -Redact uploads a redacted copy and leaves the source package untouched' {
        $pkg = Join-Path $TestDrive 'pkg'
        New-Item -ItemType Directory -Path $pkg -Force | Out-Null
        $m = Get-Content (Join-Path $script:fixtureRoot 'synthetic-manifest.json') -Raw | ConvertFrom-Json -AsHashtable
        $m | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $pkg 'audit-manifest.json')
        'node azlocal-iic-01 at 10.0.0.11' | Set-Content (Join-Path $pkg 'ranger.log')
        $before = Get-Content (Join-Path $pkg 'audit-manifest.json') -Raw

        $result = Publish-RangerRun -PackagePath $pkg -StorageAccount 'stexample' -Container 'ranger' -Include @('manifest', 'runLog') -Offline -Redact
        $result | Should -Not -BeNullOrEmpty
        $json = $result | ConvertTo-Json -Depth 20
        $json | Should -Not -Match 'azlocal-iic-01'
        $json | Should -Not -Match '10\.0\.0\.11'
        (Get-Content (Join-Path $pkg 'ranger.log') -Raw).Trim() | Should -Be 'node azlocal-iic-01 at 10.0.0.11'
        # Only the cloudPublish write-back may differ in the original manifest.
        (Get-Content (Join-Path $pkg 'audit-manifest.json') -Raw) | Should -Match 'azlocal-iic-01'
    }

    It 'config and parameter surface exposes the redact switches' {
        (Get-Command Invoke-AzureLocalRanger).Parameters.Keys | Should -Contain 'Redact'
        (Get-Command Invoke-AzureLocalRanger).Parameters.Keys | Should -Contain 'RedactMapPath'
        (Get-Command Export-AzureLocalRangerReport).Parameters.Keys | Should -Contain 'Redact'
        (Get-Command Publish-RangerRun).Parameters.Keys | Should -Contain 'Redact'
        $cfg = & (Get-Module AzureLocalRanger) { Get-RangerDefaultConfig }
        $cfg.output.redact | Should -BeFalse
    }
}
