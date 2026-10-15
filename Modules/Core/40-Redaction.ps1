# Redaction (v2.7.0): consistent, reversible-per-run pseudonyms for infrastructure identifiers.
#
# Design
#   * One context per run. The same original value always maps to the same pseudonym (case-insensitive),
#     the mapping is kept in memory and is only written to disk when the operator passes -RedactMapPath.
#   * The manifest is redacted FIRST (ConvertTo-RangerRedactedManifest); every output format is then
#     rendered from the redacted copy, so html / markdown / json / json-evidence / svg / drawio / docx /
#     xlsx / pdf / powerbi / pptx all carry pseudonyms (file names too).
#   * Free text (log files, findings text, drift reports) goes through Protect-RangerText, which is
#     idempotent: pseudonyms are recognised and never re-mapped.
#   * Pseudonyms use documentation ranges only: RFC 5737 IPv4, 2001:db8::/32, example.test, locally
#     administered MACs (02-00-5E-..).
#   * Limits (documented in docs/operator/redaction.md): guest VM names, free-form labels and resource
#     names that do not contain a registered identifier are not rewritten. Use -RedactTerm for those.

$script:RangerRedactionKinds = @('ipv4', 'ipv6', 'mac', 'host', 'fqdn', 'guid', 'serial', 'rg', 'upn', 'generic')

function Get-RangerRedactionHashBytes {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return , $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text)) }
    finally { $sha.Dispose() }
}

function New-RangerRedactionContext {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string]$Seed = [guid]::NewGuid().ToString('N'))

    $ci = [System.StringComparer]::OrdinalIgnoreCase
    return @{
        Seed        = $Seed
        Map         = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
        Reverse     = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
        Kinds       = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
        Counters    = [System.Collections.Generic.Dictionary[string, int]]::new($ci)
        Literals    = [System.Collections.Generic.List[string]]::new()
        LiteralKeys = [System.Collections.Generic.HashSet[string]]::new($ci)
        Terms       = [System.Collections.Generic.List[string]]::new()
        Embedded    = [System.Collections.Generic.List[string]]::new()
        TermKeys    = [System.Collections.Generic.HashSet[string]]::new($ci)
        HostNames   = [System.Collections.Generic.HashSet[string]]::new($ci)
        Users       = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
        Domains     = [System.Collections.Generic.Dictionary[string, string]]::new($ci)
        Cache       = $null
    }
}

function Get-RangerRedactionNumber {
    param([hashtable]$Context, [string]$Kind)
    $c = $Context['Counters']
    if (-not $c.ContainsKey($Kind)) { $c[$Kind] = 0 }
    $c[$Kind] = $c[$Kind] + 1
    return $c[$Kind]
}

function Get-RangerPseudonym {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value,
        [Parameter(Mandatory)][ValidateSet('ipv4', 'ipv6', 'mac', 'host', 'fqdn', 'guid', 'serial', 'rg', 'upn', 'generic')][string]$Kind
    )

    if ($Value.Length -eq 0) { return $Value }
    if ($Context['Map'].ContainsKey($Value)) { return $Context['Map'][$Value] }

    $lower = $Value.ToLowerInvariant()
    $pseudo = ''
    $taken = { param($p) $Context['Reverse'].ContainsKey($p) -or ($p -ieq $Value) }
    switch ($Kind) {
        'ipv4' {
            do {
                $n = Get-RangerRedactionNumber $Context 'ipv4'
                if ($n -le 762) {
                    $ranges = @('192.0.2', '198.51.100', '203.0.113')
                    $pseudo = '{0}.{1}' -f $ranges[[int][math]::Floor(($n - 1) / 254)], ((($n - 1) % 254) + 1)
                }
                else {
                    $i = $n - 763
                    if ($i -ge 65536) { throw 'Redaction: IPv4 pseudonym range exhausted.' }
                    $pseudo = '100.64.{0}.{1}' -f [int][math]::Floor($i / 256), ($i % 256)
                }
            } while (& $taken $pseudo)
        }
        'ipv6' {
            do {
                $n = Get-RangerRedactionNumber $Context 'ipv6'
                $pseudo = '2001:db8::{0:x}' -f $n
            } while (& $taken $pseudo)
        }
        'mac' {
            do {
                $n = Get-RangerRedactionNumber $Context 'mac'
                if ($n -gt 0xFFFFFF) { throw 'Redaction: MAC pseudonym range exhausted.' }
                $hex = '02005E{0:X6}' -f $n
                if ($Value -cmatch '[a-f]' -and $Value -cnotmatch '[A-F]') { $hex = $hex.ToLowerInvariant() }
                if ($Value.Contains('.')) {
                    $pseudo = '{0}.{1}.{2}' -f $hex.Substring(0, 4), $hex.Substring(4, 4), $hex.Substring(8, 4)
                }
                elseif ($Value.Contains(':') -or $Value.Contains('-')) {
                    $sep = if ($Value.Contains(':')) { ':' } else { '-' }
                    $pseudo = ((0..5 | ForEach-Object { $hex.Substring($_ * 2, 2) }) -join $sep)
                }
                else { $pseudo = $hex }
            } while (& $taken $pseudo)
        }
        'host' {
            do {
                $n = Get-RangerRedactionNumber $Context 'host'
                $pseudo = 'host-{0:D2}' -f $n
            } while (& $taken $pseudo)
            [void]$Context['HostNames'].Add($Value)
        }
        'fqdn' {
            $parts = $Value.Split('.', 2)
            if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) {
                return Get-RangerPseudonym -Context $Context -Value $Value -Kind 'generic'
            }
            $hostPseudo = Get-RangerPseudonym -Context $Context -Value $parts[0] -Kind 'host'
            $domain = $parts[1]
            if (-not $Context['Domains'].ContainsKey($domain)) {
                $dn = Get-RangerRedactionNumber $Context 'domain'
                $Context['Domains'][$domain] = "domain-$dn.example.test"
            }
            $pseudo = "$hostPseudo.example.test"
            if (& $taken $pseudo) { $pseudo = "$hostPseudo.$($Context['Domains'][$domain])" }
        }
        'guid' {
            $core = $lower.TrimStart('{').TrimEnd('}')
            $h = [Convert]::ToHexString((Get-RangerRedactionHashBytes ($Context['Seed'] + $core))).ToLowerInvariant()
            # The 5ec0de marker in the last group lets the idempotence check recognise a pseudonym GUID.
            $pseudo = '{0}-{1}-{2}-{3}-5ec0de{4}' -f $h.Substring(0, 8), $h.Substring(8, 4), $h.Substring(12, 4), $h.Substring(16, 4), $h.Substring(20, 6)
            if ($Value.StartsWith('{')) { $pseudo = '{' + $pseudo + '}' }
            if ($Value -cmatch '[A-F]' -and $Value -cnotmatch '[a-f]') { $pseudo = $pseudo.ToUpperInvariant() }
        }
        'serial' {
            $bytes = Get-RangerRedactionHashBytes ($Context['Seed'] + $lower)
            $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567'
            $bits = 0UL
            for ($i = 0; $i -lt 5; $i++) { $bits = ($bits -shl 8) -bor [ulong]$bytes[$i] }
            $sb = [System.Text.StringBuilder]::new()
            for ($i = 7; $i -ge 0; $i--) { [void]$sb.Append($alphabet[[int](($bits -shr ($i * 5)) -band 31UL)]) }
            $pseudo = 'SN-' + $sb.ToString()
        }
        'rg' {
            do {
                $n = Get-RangerRedactionNumber $Context 'rg'
                $pseudo = 'rg-redacted-{0:D2}' -f $n
            } while (& $taken $pseudo)
        }
        'upn' {
            $parts = $Value.Split('@', 2)
            if ($parts.Count -ne 2 -or -not $parts[0] -or -not $parts[1]) {
                return Get-RangerPseudonym -Context $Context -Value $Value -Kind 'generic'
            }
            if (-not $Context['Users'].ContainsKey($parts[0])) {
                $n = Get-RangerRedactionNumber $Context 'user'
                $Context['Users'][$parts[0]] = 'user-{0:D2}' -f $n
            }
            $pseudo = "$($Context['Users'][$parts[0]])@example.test"
            if (& $taken $pseudo) {
                if (-not $Context['Domains'].ContainsKey($parts[1])) {
                    $dn = Get-RangerRedactionNumber $Context 'domain'
                    $Context['Domains'][$parts[1]] = "domain-$dn.example.test"
                }
                $pseudo = "$($Context['Users'][$parts[0]])+$($Context['Domains'][$parts[1]].Split('.')[0])@example.test"
            }
        }
        default {
            do {
                $n = Get-RangerRedactionNumber $Context 'generic'
                $pseudo = 'redacted-{0:D2}' -f $n
            } while (& $taken $pseudo)
        }
    }

    if ($Context['Reverse'].ContainsKey($pseudo) -and $Kind -notin @('guid', 'serial')) {
        throw "Redaction: pseudonym collision for '$pseudo'."
    }
    $Context['Map'][$Value] = $pseudo
    if (-not $Context['Reverse'].ContainsKey($pseudo)) { $Context['Reverse'][$pseudo] = $Value }
    $Context['Kinds'][$Value] = $Kind
    return $pseudo
}

function Add-RangerRedactionLiteral {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Value,
        [Parameter(Mandatory)][ValidateSet('ipv4', 'ipv6', 'mac', 'host', 'fqdn', 'guid', 'serial', 'rg', 'upn', 'generic')][string]$Kind
    )
    if ([string]::IsNullOrWhiteSpace($Value)) { return }
    $Value = $Value.Trim()
    if ($Value.Length -lt 3 -or $Value -match '^\d+$') { return }
    # Placeholders that carry no identity are left readable.
    if ($Value -match '^(n/?a|none|null|unknown|true|false|local|localhost|not configured|not available)$') { return }
    [void](Get-RangerPseudonym -Context $Context -Value $Value -Kind $Kind)
    if ($Context['LiteralKeys'].Add($Value)) {
        $Context['Literals'].Add($Value)
        $Context['Cache'] = $null
    }
    # An FQDN also registers its short host label so bare mentions of the host are caught too.
    if ($Kind -eq 'fqdn' -and $Value.Contains('.')) {
        $short = $Value.Split('.')[0]
        if ($short.Length -ge 3 -and $short -notmatch '^\d+$') { Add-RangerRedactionLiteral -Context $Context -Value $short -Kind 'host' }
    }
    # Identifier-like names (cluster, node, resource group, serial ...) are also replaced when embedded in a
    # longer compound resource name such as csv-<cluster>-vmstore-01.
    if ($Kind -notin @('guid', 'ipv4', 'ipv6', 'mac', 'upn') -and $Value.Length -ge 6 -and
        $Value -notmatch '(?i)host|redacted|example|domain|user|term|acct|rg-|^[0-9.:-]+$' -and $Context['Embedded'] -notcontains $Value) {
        $Context['Embedded'].Add($Value)
        $Context['Cache'] = $null
    }
}

function Add-RangerRedactionTerm {
    <# Operator supplied term: replaced anywhere, even inside longer tokens (e.g. a customer short name). #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Context, [string]$Term)
    if ([string]::IsNullOrWhiteSpace($Term) -or $Term.Length -lt 2) { return }
    if ($Context['TermKeys'].Add($Term)) {
        $n = Get-RangerRedactionNumber $Context 'term'
        $p = 'term{0:D2}' -f $n
        $Context['Map'][$Term] = $p
        $Context['Reverse'][$p] = $Term
        $Context['Kinds'][$Term] = 'term'
        $Context['Terms'].Add($Term)
        $Context['Cache'] = $null
    }
}

function Get-RangerRedactionRegex {
    param([hashtable]$Context)

    if ($Context['Cache']) { return $Context['Cache'] }

    $lookup = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($literal in $Context['Literals']) {
        $lookup[$literal] = $literal
        if ($literal.Contains('\')) { $lookup[$literal.Replace('\', '\\')] = $literal }
    }
    $literalPart = if ($lookup.Count) {
        (@($lookup.Keys | Sort-Object -Property @{ Expression = { $_.Length }; Descending = $true }, @{ Expression = { $_ } }) | ForEach-Object { [regex]::Escape($_) }) -join '|'
    }
    else { '(?!)' }

    $octet = '(?:25[0-5]|2[0-4]\d|1\d{2}|[1-9]?\d)'
    $ipv4 = "(?:$octet\.){3}$octet"
    $label = '[a-z0-9_]+(?:-+[a-z0-9_]+)*'
    $generated = '(?:\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-5ec0de[0-9a-f]{6}\}?|192\.0\.2\.\d+|198\.51\.100\.\d+|203\.0\.113\.\d+|100\.64\.\d+\.\d+|2001:db8::[0-9a-f]+|02[:\-]00[:\-]5e[:\-][0-9a-f]{2}[:\-][0-9a-f]{2}[:\-][0-9a-f]{2}|0200\.5e[0-9a-f]{2}\.[0-9a-f]{4}|02005e[0-9a-f]{6}|(?:host-\d+|domain-\d+|user-\d+(?:\+domain-\d+)?)\.example\.test|user-\d+(?:\+domain-\d+)?@example\.test|example\.test|SN-[A-Z2-7]{8}|rg-redacted-\d+|host-\d+|domain-\d+|user-\d+|redacted-\d+|term\d+|acct-redacted-\d+)'
    $svcSuffix = '\.(?:(?:blob|file|queue|table|dfs|web)\.core\.windows\.net|vault\.azure\.net|azurecr\.io|servicebus\.windows\.net|gw\.arc\.azure\.com)'
    $body = "(?<generated>$generated)|(?<literal>$literalPart)|" +
    '(?<guid>\{?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\}?)|' +
    '(?<mac>(?:[0-9a-f]{2}:){5}[0-9a-f]{2}|(?:[0-9a-f]{2}-){5}[0-9a-f]{2}|(?:[0-9a-f]{4}\.){2}[0-9a-f]{4})|' +
    "(?<ipv4>$ipv4)|" +
    '(?<ipv6>(?=[0-9a-f:.]*:)[0-9a-f:]+(?:\.[0-9]{1,3}){0,4})|' +
    "(?<upn>[\w.+%-]+@$label(?:\.$label)+)|" +
    "(?<svc>[a-z0-9][a-z0-9-]{1,62}$svcSuffix)|" +
    "(?<fqdn>$label(?:\.$label)+)"
    $pattern = '(?<![a-z0-9_-])(?:' + $body + ')(?![a-z0-9_-]|\.[a-z0-9_-])'
    $opts = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $regex = [regex]::new($pattern, $opts)

    # Free-form structural rules that are not whole-token matches.
    $arm = [regex]::new('(?<=/resource[gG]roups/)[^/\s"''\\,;]+', $opts)
    $dn = [regex]::new('(?<=\b(?:CN|OU|DC|O|L|ST)=)[^,;"''\\\r\n]+', $opts)
    # SAS / bearer style secrets and SNMP communities: keep the key, drop the value.
    $secret = [regex]::new('(?<=(?:[?&;]|\b)(?:sig|sv|se|sp|st|spr|srt|ss|sr|skoid|sktid|token|access_token|apikey|api_key|key|password|pwd|passwd|secret|sharedkey|client_secret)\s*[=:]\s*)[^&\s"'';,]+|(?<=snmp-server\s+community\s+)\S+|(?<=\bcommunity\s+)(?!ro\b|rw\b)\S+', $opts)
    # DOMAIN\user (upper-case NetBIOS domain); well-known built-in authorities are left readable.
    $downlevel = [regex]::new('(?<![A-Za-z0-9\\])(?!(?:NT|AUTHORITY|SERVICE|BUILTIN|NTSERVICE|WORKGROUP|ROOT|HKLM|HKCU|SYSTEM|LOCAL|NETWORK|APPLICATION|WINDOWS|MICROSOFT)\\)[A-Z][A-Z0-9-]{1,14}\\[A-Za-z0-9._$-]{2,}(?![A-Za-z0-9._$\\-])')
    $userPath = [regex]::new('(?<=[\\/]Users[\\/])[^\\/\s"'':*?<>|]+', $opts)
    $termRegex = if ($Context['Terms'].Count) {
        [regex]::new((@($Context['Terms'] | Sort-Object -Property @{ Expression = { $_.Length }; Descending = $true } | ForEach-Object { [regex]::Escape($_) }) -join '|'), $opts)
    }
    else { $null }

    $embeddedRegex = if ($Context['Embedded'].Count) {
        [regex]::new((@($Context['Embedded'] | Sort-Object -Property @{ Expression = { $_.Length }; Descending = $true } | ForEach-Object { [regex]::Escape($_) }) -join '|'), $opts)
    }
    else { $null }
    $generatedOnly = [regex]::new('^(?:' + $generated + ')$', $opts)
    $Context['Cache'] = @{ Memo = [System.Collections.Generic.Dictionary[string, string]]::new(); Embedded = $embeddedRegex; Generated = $generatedOnly; Regex = $regex; Lookup = $lookup; Arm = $arm; Dn = $dn; Secret = $secret; Downlevel = $downlevel; UserPath = $userPath; Term = $termRegex }
    return $Context['Cache']
}

$script:RangerRedactionPrivateTlds = @('local', 'lan', 'corp', 'internal', 'intranet', 'home', 'localdomain', 'private', 'test', 'example', 'ad', 'domain', 'lab', 'priv', 'loc', 'site')
$script:RangerRedactionPublicTlds = @('com', 'net', 'org', 'edu', 'gov', 'io', 'cloud', 'co', 'us', 'uk', 'de', 'info', 'biz', 'dev', 'ca', 'au', 'eu')
$script:RangerRedactionExemptSuffix = @('microsoft.com', 'azure.com', 'windows.net', 'azure.net', 'azureedge.net', 'microsoftonline.com', 'windowsupdate.com', 'github.com', 'githubusercontent.com', 'powershellgallery.com', 'nuget.org', 'digicert.com', 'live.com', 'office.com', 'office365.com', 'visualstudio.com', 'windows.com', 'msftncsi.com', 'mozilla.org', 'w3.org', 'example.com', 'example.org', 'example.net', 'example.test', 'learn.microsoft.com')
$script:RangerRedactionFileExt = @('ps1', 'psm1', 'psd1', 'json', 'md', 'txt', 'html', 'htm', 'xml', 'csv', 'yml', 'yaml', 'docx', 'xlsx', 'pptx', 'pdf', 'svg', 'drawio', 'log', 'png', 'zip', 'dll', 'exe', 'msi', 'cab', 'sys', 'cfg', 'ini', 'conf', 'bicep')

# Dot-sourced inside Protect-RangerText so the delegates keep that frame (and the module function scope).
function Test-RangerRedactionSkip {
    param([string]$Value)
    $script:RedactCtx['Cache'].Generated.IsMatch($Value) -or $script:RedactCtx['Reverse'].ContainsKey($Value)
}

$script:RangerRedactionEvaluatorFactory = {
    $main = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $v = $m.Value
        if ($m.Groups['generated'].Success) { return $v }
        if ($m.Groups['literal'].Success) { return $script:RedactCtx['Map'][$script:RedactCtx['Cache'].Lookup[$v]] }
        if ($m.Groups['guid'].Success) {
            if ($v.StartsWith('{') -ne $v.EndsWith('}')) { return $v }
            return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'guid'
        }
        if ($m.Groups['mac'].Success) { return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'mac' }
        if ($m.Groups['ipv4'].Success) {
            if ($v -match '^(?:0\.0\.0\.0|127\.|255\.)') { return $v }
            return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'ipv4'
        }
        if ($m.Groups['ipv6'].Success) {
            $address = $null
            if (-not [System.Net.IPAddress]::TryParse($v, [ref]$address) -or
                $address.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6 -or
                $address.Equals([System.Net.IPAddress]::IPv6Loopback) -or
                $address.Equals([System.Net.IPAddress]::IPv6Any) -or
                $v -eq 'fe80::') { return $v }
            return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'ipv6'
        }
        if ($m.Groups['upn'].Success) {
            $domain = $v.Substring($v.IndexOf('@') + 1).ToLowerInvariant()
            if ($domain -in @('example.test', 'example.com')) { return $v }
            return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'upn'
        }
        if ($m.Groups['svc'].Success) { return Get-RangerPseudonymAccount -Context $script:RedactCtx -Value $v }
        if ($m.Groups['fqdn'].Success) {
            $labels = $v.Split('.')
            $last = $labels[-1].ToLowerInvariant()
            if ($script:RangerRedactionFileExt -contains $last) { return $v }
            if (@($labels | Where-Object { $_ -notmatch '^\d+$' }).Count -eq 0) { return $v }
            $isHost = $script:RedactCtx['HostNames'].Contains($labels[0])
            $tldOk = ($script:RangerRedactionPrivateTlds -contains $last) -or ($script:RangerRedactionPublicTlds -contains $last)
            if (-not $tldOk -and -not $isHost) { return $v }
            $lowerV = $v.ToLowerInvariant()
            foreach ($suffix in $script:RangerRedactionExemptSuffix) {
                if ($lowerV -eq $suffix -or $lowerV.EndsWith(".$suffix")) { return $v }
            }
            if ($labels.Count -ge 3 -or $isHost) { return Get-RangerPseudonym -Context $script:RedactCtx -Value $v -Kind 'fqdn' }
        }
        return $v
    }
    $arm = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        if (Test-RangerRedactionSkip -Value $m.Value) { return $m.Value }
        Get-RangerPseudonym -Context $script:RedactCtx -Value $m.Value -Kind 'rg'
    }
    $dn = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        if (Test-RangerRedactionSkip -Value $m.Value) { return $m.Value }
        Get-RangerPseudonym -Context $script:RedactCtx -Value $m.Value -Kind 'generic'
    }
    $secretEval = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        if ($m.Value -match '^redacted-' -or (Test-RangerRedactionSkip -Value $m.Value)) { return $m.Value }
        'redacted-secret'
    }
    $downEval = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        if (Test-RangerRedactionSkip -Value $m.Value) { return $m.Value }
        Get-RangerPseudonym -Context $script:RedactCtx -Value $m.Value -Kind 'generic'
    }
    $userPath = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        if ($m.Value -match '^(?:Public|Default|Default User|All Users)$' -or (Test-RangerRedactionSkip -Value $m.Value)) { return $m.Value }
        Get-RangerPseudonym -Context $script:RedactCtx -Value $m.Value -Kind 'generic'
    }
    $map = [System.Text.RegularExpressions.MatchEvaluator] {
        param($m)
        $script:RedactCtx['Map'][$m.Value]
    }
    @{ Main = $main; Arm = $arm; Dn = $dn; Secret = $secretEval; Downlevel = $downEval; UserPath = $userPath; Map = $map }
}
function Protect-RangerText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Text
    )
    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    $cache = Get-RangerRedactionRegex -Context $Context
    $script:RedactCtx = $Context
    $memoHit = $null
    if ($cache.Memo.TryGetValue($Text, [ref]$memoHit)) { return $memoHit }
    $lookup = $cache.Lookup

    if (-not $cache.Evaluators) { $cache.Evaluators = . $script:RangerRedactionEvaluatorFactory }
    $ev = $cache.Evaluators
    $result = $cache.Regex.Replace($Text, $ev.Main)
    if ($result.IndexOf('roups/', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $result = $cache.Arm.Replace($result, $ev.Arm) }
    if ($result.IndexOf('=') -ge 0 -or $result.IndexOf(':') -ge 0 -or $result.IndexOf('community', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
        $result = $cache.Secret.Replace($result, $ev.Secret)
        if ($result.IndexOf('=') -ge 0) { $result = $cache.Dn.Replace($result, $ev.Dn) }
    }
    if ($result.IndexOf('\') -ge 0) { $result = $cache.Downlevel.Replace($result, $ev.Downlevel) }
    if ($result.IndexOf('Users', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { $result = $cache.UserPath.Replace($result, $ev.UserPath) }
    if ($cache.Embedded) { $result = $cache.Embedded.Replace($result, $ev.Map) }
    if ($cache.Term) { $result = $cache.Term.Replace($result, $ev.Map) }    # Memoise only while the literal set is unchanged (a new literal resets Cache, and with it the memo).
    if ($Context['Cache'] -eq $cache) { $cache.Memo[$Text] = $result }
    return $result
}

function Get-RangerPseudonymAccount {
    # Storage account / vault / registry / Arc gateway first label: keep the service suffix, hide the name.
    param([hashtable]$Context, [string]$Value)
    $firstDot = $Value.IndexOf('.')
    $name = $Value.Substring(0, $firstDot)
    $rest = $Value.Substring($firstDot)
    if (-not $Context['Map'].ContainsKey($name)) {
        $n = Get-RangerRedactionNumber $Context 'acct'
        $Context['Map'][$name] = 'acct-redacted-{0:D2}' -f $n
        $Context['Reverse'][$Context['Map'][$name]] = $name
        $Context['Kinds'][$name] = 'generic'
    }
    return $Context['Map'][$name] + $rest
}

$script:RangerRedactionSerialKey = '(?i)serial|service.?tag|asset.?tag|chassis.?(tag|serial|id)|^uuid$|bios.?serial|^sn$'
$script:RangerRedactionMacKey = '(?i)mac.?address|^mac$|^permanentAddress$'
$script:RangerRedactionHostKey = '(?i)^(node|nodeName|node_name|computerName|hostName|hostNode|ownerNode|ownerNodeName|machineName|dnsHostName|sourceNode|targetNode|currentHost|clusterName|nodeFqdn|netBiosName|connectedMachineName)$'
$script:RangerRedactionFqdnKey = '(?i)^(fqdn|clusterFqdn|dnsName|dnsFqdn|host|hostname|bmcHost|bmcAddress|ipmiAddress|endpoint|dnsServer)$'
$script:RangerRedactionRgKey = '(?i)^(resourceGroup|resourceGroupName|clusterResourceGroup|rg)$'
$script:RangerRedactionDomainKey = '(?i)^(domain|domainName|dnsDomain|dnsSuffix|rootDomain|forest|forestName|userDnsDomain|adDomain|netBIOSDomain)$'
$script:RangerRedactionNameKey = '(?i)^(subscriptionName|tenantName|environmentLabel|environmentName|organization|customerName|company|siteName|location_name|workspaceName|storageAccountName|keyVaultName|vaultName|accountName|witnessAccount|dcrName|dceName)$'
$script:RangerRedactionOpaqueKey = '(?i)^(vmName|systemName|remoteSystemName|systemDescription|portDescription|switchHostname|chassisId|portId|dnsRacName|thumbprint|certThumbprint|certificateThumbprint|roleName|clusterGroupName|vlanName)$'
$script:RangerRedactionUserKey = '(?i)^(userName|upn|userPrincipalName|createdBy|owner|ownerUpn|runAsAccount|remoteIdentity|account|principalName|signedInUser|identity)$'

function Add-RangerRedactionLiteralsFromObject {
    param([hashtable]$Context, $Item, [string]$ParentKey)
    if ($null -eq $Item) { return }
    if ($Item -is [string]) {
        # string elements of node lists
        if ($ParentKey -match '(?i)^(nodeList|nodes|nodeNames|clusterNodes)$') {
            Add-RangerRedactionLiteral -Context $Context -Value $Item -Kind $(if ($Item.Contains('.')) { 'fqdn' } else { 'host' })
        }
        return
    }
    if ($Item -is [System.Collections.IDictionary]) {
        foreach ($key in @($Item.Keys)) {
            $value = $Item[$key]
            if ($key -is [string] -and $value -is [string] -and -not [string]::IsNullOrWhiteSpace($value)) {
                switch -Regex ($key) {
                    $script:RangerRedactionSerialKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'serial'; break }
                    $script:RangerRedactionMacKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'mac'; break }
                    $script:RangerRedactionHostKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind $(if ($value.Contains('.') -and $value -notmatch '^\d+(\.\d+){3}$') { 'fqdn' } else { 'host' }); break }
                    $script:RangerRedactionFqdnKey {
                        if ($value -match '^\d+(\.\d+){3}$' -or $value -match ':') { break }
                        if ($value -match '^https?://') { break }
                        Add-RangerRedactionLiteral -Context $Context -Value $value -Kind $(if ($value.Contains('.')) { 'fqdn' } else { 'host' }); break
                    }
                    $script:RangerRedactionRgKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'rg'; break }
                    $script:RangerRedactionOpaqueKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'generic'; break }
                    $script:RangerRedactionDomainKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'generic'; break }
                    $script:RangerRedactionNameKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind 'generic'; break }
                    $script:RangerRedactionUserKey { Add-RangerRedactionLiteral -Context $Context -Value $value -Kind $(if ($value.Contains('@')) { 'upn' } else { 'generic' }); break }
                    '^name$' {
                        if ($ParentKey -match '(?i)^(nodes|nodeList|machines|arcMachines|clusterNodes)$') {
                            Add-RangerRedactionLiteral -Context $Context -Value $value -Kind $(if ($value.Contains('.')) { 'fqdn' } else { 'host' })
                        }
                        break
                    }
                }
            }
            Add-RangerRedactionLiteralsFromObject -Context $Context -Item $value -ParentKey ([string]$key)
        }
        return
    }
    if ($Item -is [System.Collections.IEnumerable]) {
        foreach ($element in $Item) { Add-RangerRedactionLiteralsFromObject -Context $Context -Item $element -ParentKey $ParentKey }
    }
}

function Copy-RangerRedactedObject {
    param([hashtable]$Context, $Item)
    if ($null -eq $Item) { return $null }
    if ($Item -is [string]) { return Protect-RangerText -Context $Context -Text $Item }
    if ($Item -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Item.Keys) {
            $newKey = if ($key -is [string]) { Protect-RangerText -Context $Context -Text $key } else { $key }
            if ($copy.Contains($newKey)) { $newKey = "$newKey#$($copy.Count)" }
            $copy[$newKey] = Copy-RangerRedactedObject -Context $Context -Item $Item[$key]
        }
        return $copy
    }
    if ($Item -is [System.Collections.IEnumerable]) {
        $result = [System.Collections.Generic.List[object]]::new()
        foreach ($element in $Item) { $result.Add((Copy-RangerRedactedObject -Context $Context -Item $element)) }
        return , $result.ToArray()
    }
    return $Item
}

function ConvertTo-RangerRedactedObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [AllowNull()]$InputObject
    )
    Add-RangerRedactionLiteralsFromObject -Context $Context -Item $InputObject -ParentKey ''
    return Copy-RangerRedactedObject -Context $Context -Item $InputObject
}

function ConvertTo-RangerRedactedManifest {
    <#
    .SYNOPSIS
        Returns a redacted deep copy of a Ranger manifest and records the redaction block in run.redaction.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [hashtable]$Context,
        [string[]]$Term,
        [string]$Seed
    )
    if (-not $Context) {
        $Context = if ($Seed) { New-RangerRedactionContext -Seed $Seed } else { New-RangerRedactionContext }
    }
    foreach ($t in @($Term)) { Add-RangerRedactionTerm -Context $Context -Term $t }

    # Anchor identifiers first so the free-text pass resolves them consistently.
    $target = $Manifest['target']
    if ($target -is [System.Collections.IDictionary]) {
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['clusterFqdn']) -Kind 'fqdn'
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['clusterName']) -Kind 'host'
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['environmentLabel']) -Kind 'generic'
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['resourceGroup']) -Kind 'rg'
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['subscriptionId']) -Kind 'guid'
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$target['tenantId']) -Kind 'guid'
    }
    if ($Manifest['run'] -is [System.Collections.IDictionary]) {
        Add-RangerRedactionLiteral -Context $Context -Value ([string]$Manifest['run']['runner']) -Kind 'host'
    }

    $redacted = ConvertTo-RangerRedactedObject -Context $Context -InputObject $Manifest

    if ($redacted['run'] -is [System.Collections.IDictionary]) {
        if ($redacted['run']['baselineManifestPath']) { $redacted['run']['baselineManifestPath'] = 'redacted-baseline-path' }
        $redacted['run']['redaction'] = [ordered]@{
            enabled         = $true
            toolVersion     = (Get-RangerToolVersion)
            seedFingerprint = (Get-RangerRedactionMap -Context $Context).seedFingerprint
            mappedValues    = $Context['Map'].Count
            note            = 'Identifiers are pseudonymised. Pseudonyms are consistent within this package. The mapping is not stored here.'
        }
    }
    return $redacted
}

function Get-RangerRedactionMap {
    [CmdletBinding()]
    param([Parameter(Mandatory)][hashtable]$Context)
    $hash = Get-RangerRedactionHashBytes $Context['Seed']
    $entries = @(
        foreach ($original in ($Context['Map'].Keys | Sort-Object)) {
            [ordered]@{ kind = $Context['Kinds'][$original]; original = $original; pseudonym = $Context['Map'][$original] }
        }
    )
    return [ordered]@{
        seedFingerprint = [Convert]::ToHexString($hash).Substring(0, 8).ToLowerInvariant()
        warning         = 'This file reverses the redaction. Keep it private; never publish or upload it.'
        entries         = $entries
    }
}

function Write-RangerRedactionMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$Path,
        [string]$BaseDirectory
    )
    $target = if ([System.IO.Path]::IsPathRooted($Path) -or -not $BaseDirectory) { $Path } else { Join-Path -Path $BaseDirectory -ChildPath $Path }
    $target = [System.IO.Path]::GetFullPath($target)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    (Get-RangerRedactionMap -Context $Context) | ConvertTo-Json -Depth 10 | Set-Content -Path $target -Encoding UTF8
    return $target
}

function Protect-RangerPackageTextFiles {
    <#
    .SYNOPSIS
        Redacts every text-based file in a package in place (logs, transcripts, drift reports, CSV, JSON,
        markdown, html, svg, drawio). Binary / zipped formats are produced from the redacted manifest
        instead and are not touched here. Idempotent.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Context,
        [Parameter(Mandatory)][string]$PackageRoot,
        [string[]]$ExcludeFullPath = @()
    )
    $textExt = @('.json', '.log', '.md', '.csv', '.html', '.htm', '.svg', '.drawio', '.xml', '.txt', '.yml', '.yaml')
    $count = 0
    foreach ($file in Get-ChildItem -LiteralPath $PackageRoot -Recurse -File -ErrorAction SilentlyContinue) {
        if ($file.Extension.ToLowerInvariant() -notin $textExt) { continue }
        if ($file.FullName -in $ExcludeFullPath) { continue }
        try {
            $raw = [System.IO.File]::ReadAllText($file.FullName)
            $clean = Protect-RangerText -Context $Context -Text $raw
            if ($clean -cne $raw) {
                [System.IO.File]::WriteAllText($file.FullName, $clean, [System.Text.UTF8Encoding]::new($false))
                $count++
            }
        }
        catch {
            Write-RangerLog -Level warn -Message "Redaction: could not sweep '$($file.Name)': $($_.Exception.Message)"
        }
    }
    return $count
}







function New-RangerRedactedPackageCopy {
    <#
    .SYNOPSIS
        Builds a pseudonymised copy of an existing package in a temporary folder (used by Publish-RangerRun -Redact).
        Reports are re-rendered from the redacted manifest for every format the source package contains; the
        original package is never modified. The caller deletes the returned folder.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Manifest,
        [Parameter(Mandatory)][string]$PackagePath,
        [string[]]$Term,
        [string]$Seed
    )
    $ctx = if ($Seed) { New-RangerRedactionContext -Seed $Seed } else { New-RangerRedactionContext }
    $redacted = ConvertTo-RangerRedactedManifest -Manifest $Manifest -Context $ctx -Term $Term

    $tempRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('ranger-redacted-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $redacted | ConvertTo-Json -Depth 100 | Set-Content -Path (Join-Path $tempRoot 'audit-manifest.json') -Encoding UTF8

    $typeToFormat = @{
        'html-report' = 'html'; 'markdown-report' = 'markdown'; 'docx-report' = 'docx'; 'pdf-report' = 'pdf'
        'xlsx-workbook' = 'xlsx'; 'pptx' = 'pptx'; 'json-evidence' = 'json-evidence'; 'powerbi-bundle' = 'powerbi'
        'svg-diagram' = 'svg'; 'drawio-diagram' = 'drawio'; 'diagram-svg' = 'svg'; 'diagram-drawio' = 'drawio'
    }
    $formats = New-Object System.Collections.Generic.List[string]
    foreach ($a in @($Manifest['artifacts'])) {
        $type = [string]$a['type']
        if ($typeToFormat.ContainsKey($type) -and -not $formats.Contains($typeToFormat[$type])) { $formats.Add($typeToFormat[$type]) }
    }
    # Diagram artefacts are detected by folder content as well, because the artifact type names vary by version.
    $diagramsDir = Join-Path $PackagePath 'diagrams'
    if (Test-Path -LiteralPath $diagramsDir) {
        if ((Get-ChildItem -LiteralPath $diagramsDir -Filter '*.svg' -File -ErrorAction SilentlyContinue) -and -not $formats.Contains('svg')) { $formats.Add('svg') }
        if ((Get-ChildItem -LiteralPath $diagramsDir -Filter '*.drawio' -File -ErrorAction SilentlyContinue) -and -not $formats.Contains('drawio')) { $formats.Add('drawio') }
    }
    if ($formats.Count -gt 0) {
        $null = Invoke-RangerOutputGeneration -Manifest $redacted -PackageRoot $tempRoot -Formats @($formats) -Mode ([string]$redacted['run']['mode'])
    }

    foreach ($name in @('ranger.log', 'run-status.json', 'package-index.json')) {
        $src = Join-Path $PackagePath $name
        if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $tempRoot $name) -Force }
    }
    $null = Protect-RangerPackageTextFiles -Context $ctx -PackageRoot $tempRoot
    return [ordered]@{ PackagePath = $tempRoot; Manifest = $redacted; Context = $ctx }
}
