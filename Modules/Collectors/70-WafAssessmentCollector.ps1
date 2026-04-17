function Resolve-RangerManifestPath {
    <#
    .SYNOPSIS
        Resolves a dot-notation path against the audit manifest hashtable.
    .DESCRIPTION
        Walks the manifest using dot-separated path segments and returns the value
        at that location. Returns $null if any segment is missing or the path is invalid.
        Supports IDictionary (hashtable / ordered hashtable) and PSObject properties.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $segments = $Path -split '\.'
    $current  = $Manifest
    foreach ($seg in $segments) {
        if ($null -eq $current) { return $null }
        if ($current -is [System.Collections.IDictionary]) {
            if (-not $current.Contains($seg)) { return $null }
            $current = $current[$seg]
        } elseif ($null -ne $current.PSObject) {
            $prop = $current.PSObject.Properties[$seg]
            if ($null -eq $prop) { return $null }
            $current = $prop.Value
        } else {
            return $null
        }
    }
    return $current
}

function Invoke-RangerWafCalculation {
    <#
    .SYNOPSIS
        v1.6.0 (#214): compute a named aggregate metric from the manifest.
    .DESCRIPTION
        Supports aggregates: min, max, avg, sum, count, pct (percentage of
        truthy values). `source` is a manifestPath that resolves to an array
        (or array-like); `field` is the property to aggregate per element.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $true)]
        $Definition
    )

    $source = $Definition.source
    $field  = $Definition.field
    $agg    = [string]($Definition.aggregate)

    if ([string]::IsNullOrWhiteSpace($source) -or [string]::IsNullOrWhiteSpace($agg)) {
        return $null
    }

    $raw = Resolve-RangerManifestPath -Manifest $Manifest -Path $source
    $collection = @($raw | Where-Object { $_ -ne $null })
    if ($collection.Count -eq 0) { return $null }

    # When field is specified, project each element; otherwise treat the item itself as the value.
    $values = if ([string]::IsNullOrWhiteSpace($field)) {
        $collection
    } else {
        @($collection | ForEach-Object {
            if ($_ -is [System.Collections.IDictionary]) { $_[$field] }
            elseif ($_.PSObject -and $_.PSObject.Properties[$field]) { $_.$field }
            else { $null }
        })
    }

    switch ($agg) {
        'min' {
            $numeric = @($values | Where-Object { $_ -ne $null } | ForEach-Object { $_ -as [double] } | Where-Object { $null -ne $_ })
            if ($numeric.Count -eq 0) { return $null }
            return [double]($numeric | Measure-Object -Minimum).Minimum
        }
        'max' {
            $numeric = @($values | Where-Object { $_ -ne $null } | ForEach-Object { $_ -as [double] } | Where-Object { $null -ne $_ })
            if ($numeric.Count -eq 0) { return $null }
            return [double]($numeric | Measure-Object -Maximum).Maximum
        }
        'avg' {
            $numeric = @($values | Where-Object { $_ -ne $null } | ForEach-Object { $_ -as [double] } | Where-Object { $null -ne $_ })
            if ($numeric.Count -eq 0) { return $null }
            return [double]($numeric | Measure-Object -Average).Average
        }
        'sum' {
            $numeric = @($values | Where-Object { $_ -ne $null } | ForEach-Object { $_ -as [double] } | Where-Object { $null -ne $_ })
            if ($numeric.Count -eq 0) { return 0 }
            return [double]($numeric | Measure-Object -Sum).Sum
        }
        'count' {
            return [int]$collection.Count
        }
        'pct' {
            if ($collection.Count -eq 0) { return 0 }
            $truthy = @($values | Where-Object { $_ -eq $true -or $_ -eq 1 -or ($_ -is [string] -and $_ -in @('true','True','yes','ok','healthy')) }).Count
            return [math]::Round(($truthy / $collection.Count) * 100, 1)
        }
        default { return $null }
    }
}

function Invoke-RangerWafRuleEvaluation {
    <#
    .SYNOPSIS
        Evaluates WAF rules from waf-rules.json against the audit manifest.
    .DESCRIPTION
        Loads the rule definitions from config/waf-rules.json in the module root,
        evaluates each rule against the current manifest, and returns a structured
        result object per pillar suitable for the WAF Scorecard report section.

        Rules do not require re-collection - this function can be called against any
        saved manifest by regenerating reports with Export-AzureLocalRangerReport.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    # Locate waf-rules.json relative to the installed module
    $moduleBase  = (Get-Module AzureLocalRanger -ErrorAction SilentlyContinue).ModuleBase
    $rulesPath   = if ($moduleBase) { Join-Path $moduleBase 'config/waf-rules.json' } else { $null }
    $rulesData   = $null

    if ($rulesPath -and (Test-Path -Path $rulesPath -PathType Leaf)) {
        try {
            $rulesData = Get-Content -Path $rulesPath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "WAF rule evaluation: failed to load waf-rules.json - $($_.Exception.Message)"
        }
    }

    if ($null -eq $rulesData -or @($rulesData.rules).Count -eq 0) {
        return [ordered]@{
            pillarScores   = @()
            ruleResults    = @()
            advisorFindings = @()
            summary        = [ordered]@{ totalRules = 0; passingRules = 0; overallScore = 0; status = 'no-rules' }
        }
    }

    # v1.6.0 (#214): pre-compute named calculations once so rules can reference
    # aggregate metrics (min/avg/max/sum/pct) by name.
    $calculations = @{}
    if ($rulesData.calculations) {
        foreach ($calcName in @($rulesData.calculations.PSObject.Properties.Name)) {
            $def = $rulesData.calculations.$calcName
            try {
                $calculations[$calcName] = Invoke-RangerWafCalculation -Manifest $Manifest -Definition $def
            } catch {
                Write-Warning "WAF calculation '$calcName' failed: $($_.Exception.Message)"
                $calculations[$calcName] = $null
            }
        }
    }

    $ruleResults = New-Object System.Collections.ArrayList

    foreach ($rule in $rulesData.rules) {
        # v1.6.0 (#214): graduated threshold scoring path — rule has a named
        # `calculation` reference and a `thresholds` array (descending min).
        if ($rule.calculation -and $rule.thresholds) {
            $value = $calculations[[string]$rule.calculation]
            $maxPts = if ($null -ne $rule.maxPoints) { [int]$rule.maxPoints } elseif ($null -ne $rule.points) { [int]$rule.points } else { 1 }

            if ($null -eq $value) {
                Write-Warning "WAF rule '$($rule.id)' references undefined or null calculation '$($rule.calculation)' — skipping."
                [void]$ruleResults.Add([ordered]@{
                    id             = $rule.id
                    pillar         = $rule.pillar
                    title          = $rule.title
                    description    = $rule.description
                    severity       = $rule.severity
                    recommendation = $rule.recommendation
                    calculation    = [string]$rule.calculation
                    resolvedValue  = $null
                    awardedPoints  = 0
                    maxPoints      = $maxPts
                    pass           = $false
                    band           = 'skipped'
                    message        = "Calculation '$($rule.calculation)' not available."
                })
                continue
            }

            # Sort thresholds descending by `min`, take first matching band.
            $numeric  = [double]($value -as [double])
            $ordered  = @($rule.thresholds | Sort-Object { [double]$_.min } -Descending)
            $band     = $ordered | Where-Object { $numeric -ge [double]$_.min } | Select-Object -First 1
            if (-not $band) { $band = $ordered | Select-Object -Last 1 }
            $awarded  = if ($band) { [int]$band.points } else { 0 }
            $label    = if ($band -and $band.label) { [string]$band.label } else { 'Unknown' }
            $pass     = $awarded -ge $maxPts
            $msgKey   = if ($pass) { 'passMessage' } elseif ($awarded -gt 0) { 'warningMessage' } else { 'failMessage' }
            $template = [string]$rule.$msgKey
            $formatted = if ($numeric -eq [math]::Floor($numeric)) { [string][int]$numeric } else { '{0:N1}' -f $numeric }
            $message  = if ($template) { $template -replace '\{value\}', $formatted } else { "$label ($formatted)" }

            # v2.0.0 (#225): weight applies. Graduated bands already compute awarded/maxPts
            # fractional credit; weight multiplies both sides so the pillar roll-up mixes
            # weighted rules correctly.
            $weight           = if ($null -ne $rule.weight) { [double]$rule.weight } else { 1.0 }
            $weightedAwarded  = [double]$awarded * $weight
            $weightedMaxPts   = [double]$maxPts * $weight

            [void]$ruleResults.Add([ordered]@{
                id               = $rule.id
                pillar           = $rule.pillar
                title            = $rule.title
                description      = $rule.description
                severity         = $rule.severity
                recommendation   = $rule.recommendation
                remediation      = if ($null -ne $rule.remediation) { ConvertTo-RangerHashtable -InputObject $rule.remediation } else { $null }
                calculation      = [string]$rule.calculation
                resolvedValue    = $numeric
                awardedPoints    = $awarded
                maxPoints        = $maxPts
                weight           = $weight
                weightedAwarded  = $weightedAwarded
                weightedMaxPoints = $weightedMaxPts
                pass             = $pass
                band             = $label
                message          = $message
            })
            continue
        }

        $rawValue = Resolve-RangerManifestPath -Manifest $Manifest -Path $rule.manifestPath
        $pass     = switch ($rule.check) {
            'equals'           {
                $null -ne $rawValue -and [string]$rawValue -eq [string]$rule.expected
            }
            'notEquals'        {
                [string]$rawValue -ne [string]$rule.expected
            }
            'greaterThan'      {
                $null -ne $rawValue -and $rawValue -isnot [array] -and
                    [double]($rawValue -as [double]) -gt [double]$rule.threshold
            }
            'lessThan'         {
                $null -ne $rawValue -and $rawValue -isnot [array] -and
                    [double]($rawValue -as [double]) -lt [double]$rule.threshold
            }
            'greaterThanOrEqual' {
                $null -ne $rawValue -and [double]($rawValue -as [double]) -ge [double]$rule.threshold
            }
            'lessThanOrEqual'  {
                $null -ne $rawValue -and [double]($rawValue -as [double]) -le [double]$rule.threshold
            }
            'notNull'          {
                $null -ne $rawValue -and [string]$rawValue -ne '' -and
                    [string]$rawValue -ne '(not recorded)' -and [string]$rawValue -ne 'null'
            }
            'boolTrue'         { $rawValue -eq $true }
            'boolFalse'        { $rawValue -eq $false }
            'countGreaterThan' { @($rawValue).Count -gt [int]$rule.threshold }
            'countEquals'      { @($rawValue).Count -eq [int]$rule.expected }
            default            { $false }
        }

        # Existing pass/fail rules award full points on pass, 0 on fail (#214).
        # v2.0.0 (#225): warnings now award 0.5 × weight (graduated credit for
        # informational/warning severity rules that don't have explicit graduated bands).
        $maxPts  = if ($null -ne $rule.maxPoints) { [int]$rule.maxPoints } elseif ($null -ne $rule.points) { [int]$rule.points } else { 1 }
        $warnSev = [string]$rule.severity -in @('warning', 'informational')
        $awarded = if ($pass) { $maxPts } elseif ($warnSev -and $null -ne $rawValue) { [double]($maxPts * 0.5) } else { 0 }

        $weight           = if ($null -ne $rule.weight) { [double]$rule.weight } else { 1.0 }
        $weightedAwarded  = [double]$awarded * $weight
        $weightedMaxPts   = [double]$maxPts   * $weight

        [void]$ruleResults.Add([ordered]@{
            id                = $rule.id
            pillar            = $rule.pillar
            title             = $rule.title
            description       = $rule.description
            severity          = $rule.severity
            recommendation    = $rule.recommendation
            remediation       = if ($null -ne $rule.remediation) { ConvertTo-RangerHashtable -InputObject $rule.remediation } else { $null }
            manifestPath      = $rule.manifestPath
            resolvedValue     = $rawValue
            awardedPoints     = $awarded
            maxPoints         = $maxPts
            weight            = $weight
            weightedAwarded   = $weightedAwarded
            weightedMaxPoints = $weightedMaxPts
            pass              = $pass
        })
    }

    # v2.0.0 (#225): aggregate per-pillar scores using weightedAwarded / weightedMaxPoints
    # so weight-3 rules count 3× a weight-1 rule; warnings automatically count 0.5× via
    # the fractional awarded points computed above.
    $pillarOrder  = @('Reliability', 'Security', 'Cost Optimization', 'Operational Excellence', 'Performance Efficiency')
    $pillarScores = New-Object System.Collections.ArrayList

    # Resolve v2.0.0 #225 score thresholds from waf-rules.json, with sensible fallbacks.
    $thresh = [ordered]@{ excellent = 80; good = 60; fair = 40; needsImprovement = 0 }
    if ($rulesData.scoreThresholds) {
        foreach ($k in @('excellent','good','fair','needsImprovement')) {
            if ($null -ne $rulesData.scoreThresholds.$k) { $thresh[$k] = [int]$rulesData.scoreThresholds.$k }
        }
    }

    $statusFor = {
        param([double]$s)
        if ($s -ge $thresh.excellent)        { return 'Excellent' }
        elseif ($s -ge $thresh.good)         { return 'Good' }
        elseif ($s -ge $thresh.fair)         { return 'Fair' }
        else                                  { return 'Needs Improvement' }
    }

    foreach ($pillar in $pillarOrder) {
        $pillarRules = @($ruleResults | Where-Object { $_.pillar -eq $pillar })
        $total       = $pillarRules.Count
        $passing     = @($pillarRules | Where-Object { $_.pass -eq $true }).Count
        # Hashtables don't expose keys as object properties for Measure-Object, so sum manually.
        $awarded = 0.0
        $maxPts  = 0.0
        foreach ($rr in $pillarRules) { $awarded += [double]$rr.weightedAwarded; $maxPts += [double]$rr.weightedMaxPoints }
        $score   = if ($maxPts -gt 0) { [int][math]::Round($awarded / $maxPts * 100) } else { 0 }
        $status      = & $statusFor $score
        $topFinding = @($pillarRules | Where-Object { $_.pass -eq $false } | Sort-Object {
            switch ($_.severity) { 'critical' { 0 } 'warning' { 1 } default { 2 } }
        } | Select-Object -First 1)

        [void]$pillarScores.Add([ordered]@{
            pillar       = $pillar
            total        = $total
            passing      = $passing
            score        = $score
            status       = $status
            topFinding   = if ($topFinding.Count -gt 0) { $topFinding[0].title } else { '-' }
            topSeverity  = if ($topFinding.Count -gt 0) { $topFinding[0].severity } else { '-' }
            weightedAwarded = [math]::Round($awarded, 2)
            weightedMax     = [math]::Round($maxPts, 2)
        })
    }

    $allRules     = @($ruleResults)
    $allPass      = @($allRules | Where-Object { $_.pass -eq $true }).Count
    $totalAwarded = 0.0
    $totalMax     = 0.0
    foreach ($rr in $allRules) { $totalAwarded += [double]$rr.weightedAwarded; $totalMax += [double]$rr.weightedMaxPoints }
    $overall      = if ($totalMax -gt 0) { [int][math]::Round($totalAwarded / $totalMax * 100) } else { 0 }

    # v2.2.0 (#241): compute priorityScore per rule and bucket failing rules into
    # Now/Next/Later tiers. priorityScore = (weight * severityMult * impactFactor) / effortFactor.
    $priority = $rulesData.prioritization
    $sevMap  = @{ critical = 3; warning = 2; informational = 1 }
    $impMap  = @{ high = 3; medium = 2; low = 1 }
    $effMap  = @{ S = 1; M = 2; L = 4 }
    $defEff  = 'M'
    $defImp  = 'medium'
    if ($priority) {
        if ($priority.severityMultipliers) { foreach ($k in @('critical','warning','informational')) { if ($null -ne $priority.severityMultipliers.$k) { $sevMap[$k] = [int]$priority.severityMultipliers.$k } } }
        if ($priority.impactFactors)       { foreach ($k in @('high','medium','low'))               { if ($null -ne $priority.impactFactors.$k)       { $impMap[$k] = [int]$priority.impactFactors.$k } } }
        if ($priority.effortFactors)       { foreach ($k in @('S','M','L'))                          { if ($null -ne $priority.effortFactors.$k)       { $effMap[$k] = [int]$priority.effortFactors.$k } } }
        if (-not [string]::IsNullOrWhiteSpace([string]$priority.defaultEffort)) { $defEff = [string]$priority.defaultEffort }
        if (-not [string]::IsNullOrWhiteSpace([string]$priority.defaultImpact)) { $defImp = [string]$priority.defaultImpact }
    }

    foreach ($rr in $allRules) {
        $effort = if ($rr.remediation -and -not [string]::IsNullOrWhiteSpace([string]$rr.remediation.estimatedEffort)) { [string]$rr.remediation.estimatedEffort } else { $defEff }
        $impact = if ($rr.remediation -and -not [string]::IsNullOrWhiteSpace([string]$rr.remediation.estimatedImpact)) { [string]$rr.remediation.estimatedImpact } else { $defImp }
        $sev    = [string]$rr.severity
        $sevMul = if ($sevMap.ContainsKey($sev)) { $sevMap[$sev] } else { 1 }
        $impFac = if ($impMap.ContainsKey($impact)) { $impMap[$impact] } else { 2 }
        $effFac = if ($effMap.ContainsKey($effort)) { $effMap[$effort] } else { 2 }
        $w      = if ($null -ne $rr.weight) { [double]$rr.weight } else { 1.0 }
        $score  = if ($effFac -gt 0) { [math]::Round(($w * $sevMul * $impFac) / $effFac, 2) } else { 0 }
        $rr['estimatedEffort'] = $effort
        $rr['estimatedImpact'] = $impact
        $rr['priorityScore']   = [double]$score
    }

    # Bucket failing rules by priorityScore: top third Now, middle Next, rest Later.
    $failing = @($allRules | Where-Object { $_.pass -eq $false } | Sort-Object -Property @{ Expression = { -[double]$_.priorityScore } }, @{ Expression = { [string]$_.id } })
    $roadmap = New-Object System.Collections.ArrayList
    if ($failing.Count -gt 0) {
        $perTier = [math]::Max(1, [int][math]::Ceiling($failing.Count / 3.0))
        for ($i = 0; $i -lt $failing.Count; $i++) {
            $tier = if ($i -lt $perTier) { 'Now' } elseif ($i -lt ($perTier * 2)) { 'Next' } else { 'Later' }
            $rr = $failing[$i]
            $firstStep = if ($rr.remediation -and @($rr.remediation.steps).Count -gt 0) { [string]@($rr.remediation.steps)[0] } else { [string]$rr.recommendation }
            [void]$roadmap.Add([ordered]@{
                bucket        = $tier
                id            = [string]$rr.id
                pillar        = [string]$rr.pillar
                severity      = [string]$rr.severity
                weight        = [double]$rr.weight
                effort        = [string]$rr.estimatedEffort
                impact        = [string]$rr.estimatedImpact
                priorityScore = [double]$rr.priorityScore
                title         = [string]$rr.title
                firstStep     = $firstStep
            })
        }
    }

    # v2.2.0 (#242): greedy gap-to-goal projection — simulate closing failing rules in
    # order of deltaScore/effortFactor until we cross the next threshold (Good or Excellent).
    $gapToGoal = Invoke-RangerWafGapToGoal -RuleResults $allRules -TotalAwarded $totalAwarded -TotalMax $totalMax -Thresholds $thresh -EffortMap $effMap

    return [ordered]@{
        pillarScores    = @($pillarScores)
        ruleResults     = @($ruleResults)
        scoreThresholds = $thresh
        roadmap         = @($roadmap)
        gapToGoal       = $gapToGoal
        summary         = [ordered]@{
            totalRules       = $allRules.Count
            passingRules     = $allPass
            failingRules     = $allRules.Count - $allPass
            overallScore     = $overall
            weightedAwarded  = [math]::Round($totalAwarded, 2)
            weightedMax      = [math]::Round($totalMax, 2)
            status           = & $statusFor $overall
        }
    }
}

function Invoke-RangerWafGapToGoal {
    <#
    .SYNOPSIS
        v2.2.0 (#242): greedy fix-plan projection — "fix these N rules to reach <threshold>%".
    .DESCRIPTION
        Simulates closing failing rules in order of `deltaScore / effortFactor` descending,
        stopping when the projected overall score crosses the next threshold (Good 60% or
        Excellent 80%) or after `MaxPlanEntries` (default 5). Honours rule dependencies —
        a dependent rule cannot be closed before its prerequisites.
    #>
    param(
        [Parameter(Mandatory = $true)] $RuleResults,
        [Parameter(Mandatory = $true)] [double]$TotalAwarded,
        [Parameter(Mandatory = $true)] [double]$TotalMax,
        [Parameter(Mandatory = $true)] $Thresholds,
        [Parameter(Mandatory = $true)] $EffortMap,
        [int]$MaxPlanEntries = 5
    )

    if ($TotalMax -le 0) { return $null }
    $current = [int][math]::Round($TotalAwarded / $TotalMax * 100)
    $statusFor = {
        param([double]$s)
        if ($s -ge $Thresholds.excellent) { 'Excellent' }
        elseif ($s -ge $Thresholds.good)  { 'Good' }
        elseif ($s -ge $Thresholds.fair)  { 'Fair' }
        else                               { 'Needs Improvement' }
    }
    $currentStatus = & $statusFor $current
    $failing = @($RuleResults | Where-Object { $_.pass -eq $false })
    if ($failing.Count -eq 0) {
        return [ordered]@{
            currentScore    = $current
            currentStatus   = $currentStatus
            projectedScore  = $current
            projectedStatus = $currentStatus
            targetThreshold = $null
            fixPlan         = @()
            message         = 'No failing rules — already at target posture.'
        }
    }

    $target = if ($current -lt $Thresholds.good) { 'good' } elseif ($current -lt $Thresholds.excellent) { 'excellent' } else { 'excellent' }
    $targetScore = if ($target -eq 'good') { [int]$Thresholds.good } else { [int]$Thresholds.excellent }

    # Annotate each failing rule with projected delta.
    $candidates = New-Object System.Collections.ArrayList
    foreach ($rr in $failing) {
        $effort = if ($rr.estimatedEffort) { [string]$rr.estimatedEffort } else { 'M' }
        $effFac = if ($EffortMap.ContainsKey($effort)) { [int]$EffortMap[$effort] } else { 2 }
        $remaining = [double]$rr.weightedMaxPoints - [double]$rr.weightedAwarded
        if ($remaining -le 0) { continue }
        $deltaScore = [math]::Round(($remaining / $TotalMax) * 100, 2)
        $efficiency = if ($effFac -gt 0) { [math]::Round($deltaScore / $effFac, 3) } else { 0 }
        $deps = @()
        if ($rr.remediation -and $rr.remediation.dependencies) { $deps = @($rr.remediation.dependencies | ForEach-Object { [string]$_ }) }
        [void]$candidates.Add([ordered]@{
            id         = [string]$rr.id
            effort     = $effort
            effFac     = $effFac
            remaining  = [double]$remaining
            deltaScore = [double]$deltaScore
            efficiency = [double]$efficiency
            deps       = $deps
        })
    }

    # Greedy selection honouring dependencies.
    $plan    = New-Object System.Collections.ArrayList
    $closed  = New-Object System.Collections.Generic.HashSet[string]
    $passing = New-Object System.Collections.Generic.HashSet[string]
    foreach ($rr in $RuleResults) { if ($rr.pass -eq $true) { [void]$passing.Add([string]$rr.id) } }

    $projAwarded = $TotalAwarded
    for ($i = 0; $i -lt $MaxPlanEntries; $i++) {
        $available = @($candidates | Where-Object {
            -not $closed.Contains($_.id) -and (@($_.deps | Where-Object { $_ -and -not $passing.Contains($_) -and -not $closed.Contains($_) }).Count -eq 0)
        })
        if ($available.Count -eq 0) { break }
        $pick = $available | Sort-Object -Property @{ Expression = { -[double]$_.efficiency } }, @{ Expression = { [string]$_.id } } | Select-Object -First 1
        $projAwarded += [double]$pick.remaining
        $cum = [int][math]::Round($projAwarded / $TotalMax * 100)
        [void]$closed.Add([string]$pick.id)
        [void]$plan.Add([ordered]@{
            ruleId          = [string]$pick.id
            deltaScore      = [double]$pick.deltaScore
            cumulativeScore = [int]$cum
            effort          = [string]$pick.effort
        })
        if ($cum -ge $targetScore) { break }
    }

    $projected = [int][math]::Round($projAwarded / $TotalMax * 100)
    $projectedStatus = & $statusFor $projected

    return [ordered]@{
        currentScore    = $current
        currentStatus   = $currentStatus
        projectedScore  = $projected
        projectedStatus = $projectedStatus
        targetThreshold = $target
        fixPlan         = @($plan)
    }
}

function Invoke-RangerWafAssessmentCollector {
    <#
    .SYNOPSIS
        Queries Azure Advisor for WAF-relevant recommendations for the Azure Local cluster.
    .DESCRIPTION
        Calls Get-AzAdvisorRecommendation for the configured subscription, filters results
        to the resource group and HCI resource types, and maps Advisor categories to WAF
        pillars. The returned wafAssessment domain is stored in the manifest and used by
        Invoke-RangerWafRuleEvaluation at report-generation time.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Config,

        [Parameter(Mandatory = $true)]
        $CredentialMap,

        [Parameter(Mandatory = $true)]
        [object]$Definition,

        [Parameter(Mandatory = $true)]
        [string]$PackageRoot
    )

    $fixture = Get-RangerCollectorFixtureData -Config $Config -CollectorId $Definition.Id
    if ($fixture) {
        return ConvertTo-RangerHashtable -InputObject $fixture
    }

    # Advisor category -> WAF pillar mapping
    $categoryMap = @{
        HighAvailability       = 'Reliability'
        Security               = 'Security'
        Cost                   = 'Cost Optimization'
        OperationalExcellence  = 'Operational Excellence'
        Performance            = 'Performance Efficiency'
    }

    $advisorRecommendations = @(
        Invoke-RangerSafeAction -Label 'Azure Advisor recommendations' -DefaultValue @() -ScriptBlock {
            Invoke-RangerAzureQuery -AzureCredentialSettings $CredentialMap.azure -ArgumentList @($Config.targets.azure.subscriptionId, $Config.targets.azure.resourceGroup) -ScriptBlock {
                param($SubscriptionId, $ResourceGroup)
                if (-not (Get-Command -Name Get-AzAdvisorRecommendation -ErrorAction SilentlyContinue)) { return @() }
                if ([string]::IsNullOrWhiteSpace($SubscriptionId)) { return @() }

                $allRecs = @(Get-AzAdvisorRecommendation -ErrorAction SilentlyContinue)
                $hciTypes = @('microsoft.azurestackhci/clusters', 'microsoft.hybridcompute/machines', 'microsoft.azurestackhci')

                # Filter to the configured resource group and HCI-relevant resource types where possible
                $filtered = @($allRecs | Where-Object {
                    $r = $_
                    $inRg    = [string]::IsNullOrWhiteSpace($ResourceGroup) -or ($r.ImpactedField -match $ResourceGroup -or $r.ResourceId -match $ResourceGroup)
                    $isHci   = $hciTypes | ForEach-Object { $r.ImpactedField -match $_ -or $r.ImpactedValue -match $_ } | Where-Object { $_ }
                    $inRg -or $isHci.Count -gt 0
                })

                # If nothing matched the filter, return the broader subscription results
                if ($filtered.Count -eq 0) { $filtered = @($allRecs | Select-Object -First 50) }

                @($filtered | ForEach-Object {
                    $r       = $_
                    $cat     = [string]$r.Category
                    [ordered]@{
                        id              = $r.Name
                        category        = $cat
                        wafPillar       = if ($cat -and $categoryMap.ContainsKey($cat)) { $categoryMap[$cat] } else { 'Operational Excellence' }
                        impact          = [string]$r.Impact
                        impactedField   = $r.ImpactedField
                        impactedValue   = $r.ImpactedValue
                        shortDescription = [string]$r.ShortDescription.Problem
                        remediation     = [string]$r.ShortDescription.Solution
                        score           = if ($null -ne $r.Score) { [double]$r.Score } else { 0 }
                        lastUpdated     = [string]$r.LastUpdated
                        resourceId      = $r.ResourceId
                    }
                })
            }
        }
    )

    # Group Advisor recommendations by WAF pillar
    $byPillar = New-Object System.Collections.ArrayList
    foreach ($pillar in @('Reliability', 'Security', 'Cost Optimization', 'Operational Excellence', 'Performance Efficiency')) {
        $pillarRecs = @($advisorRecommendations | Where-Object { $_.wafPillar -eq $pillar })
        [void]$byPillar.Add([ordered]@{
            pillar = $pillar
            count  = $pillarRecs.Count
            highImpactCount = @($pillarRecs | Where-Object { $_.impact -match 'High' }).Count
            recommendations = @($pillarRecs)
        })
    }

    $findings = New-Object System.Collections.ArrayList

    if ($advisorRecommendations.Count -eq 0) {
        [void]$findings.Add((New-RangerFinding -Severity informational -Title 'No Azure Advisor recommendations retrieved' -Description 'The WAF assessment collector could not retrieve Azure Advisor recommendations. This may be because the Az.Advisor module is not installed, no subscription context was provided, or no recommendations are currently active.' -CurrentState 'advisor data not collected' -Recommendation 'Install the Az.Advisor module and ensure a valid subscriptionId is configured to enable Advisor-based WAF recommendations.'))
    }

    $highImpactCount = @($advisorRecommendations | Where-Object { $_.impact -match 'High' }).Count
    if ($highImpactCount -gt 0) {
        [void]$findings.Add((New-RangerFinding -Severity warning -Title "Azure Advisor has $highImpactCount high-impact recommendation(s) for this environment" -Description "Azure Advisor returned $highImpactCount High-impact recommendation(s). Review the WAF Assessment section of the report for details." -CurrentState "$highImpactCount high-impact Advisor recommendations" -Recommendation 'Review each high-impact recommendation in the Azure portal Advisor blade and create work items to address before handoff.'))
    }

    return @{
        Status   = 'success'
        Domains  = @{
            wafAssessment = [ordered]@{
                advisorRecommendations = ConvertTo-RangerHashtable -InputObject $advisorRecommendations
                byPillar               = ConvertTo-RangerHashtable -InputObject $byPillar
                summary                = [ordered]@{
                    totalAdvisorRecommendations = $advisorRecommendations.Count
                    highImpactCount             = $highImpactCount
                    mediumImpactCount           = @($advisorRecommendations | Where-Object { $_.impact -match 'Medium' }).Count
                    lowImpactCount              = @($advisorRecommendations | Where-Object { $_.impact -match 'Low' }).Count
                    pillarBreakdown             = @($byPillar | ForEach-Object { [ordered]@{ pillar = $_.pillar; count = $_.count } })
                }
            }
        }
        Findings      = @($findings)
        Relationships = @()
        RawEvidence   = [ordered]@{
            advisorRecommendations = ConvertTo-RangerHashtable -InputObject $advisorRecommendations
        }
    }
}
