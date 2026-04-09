Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Get-Location
$outDir = Join-Path $root 'outputs'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$records = New-Object System.Collections.Generic.List[object]
$recordSigSet = New-Object System.Collections.Generic.HashSet[string]

function Normalize-Species([string]$s) {
    if ($null -eq $s) { return '' }
    $x = $s.Trim()
    $x = $x -replace '\[',''
    $x = $x -replace '\]',''
    $x = $x -replace '\s+type=.*$',''
    # Normalize split charge formatting from mixed sources.
    $x = [regex]::Replace($x, '\s*([+-])\s*(\d+)\s*$', '$1$2')
    $x = [regex]::Replace($x, '\s*(\d+)\s*([+-])\s*$', '$2$1')
    if ($x -match '^(.*?)(\+{2,})$') { $x = ($matches[1] + '+' + $matches[2].Length) }
    elseif ($x -match '^(.*?)(-{2,})$') { $x = ($matches[1] + '-' + $matches[2].Length) }
    elseif ($x -match '^(.*?)(\d+)([+-])$') { $x = ($matches[1] + $matches[3] + $matches[2]) }
    if ($x -match '^(.*?)([+-])1$') { $x = ($matches[1] + $matches[2]) }
    $x = $x -replace '\s+',' '
    return $x
}

function Normalize-EquationDisplay([string]$eq) {
    if ([string]::IsNullOrWhiteSpace($eq)) { return '' }
    $raw = ($eq -replace '\s+',' ').Trim()
    if ($raw -notmatch '=') { return $raw }
    $parts = $raw -split '='
    if ($parts.Count -ne 2) { return $raw }
    $normSide = {
        param([string]$side)
        $terms = $side.Trim() -split '\s+\+\s+'
        $out = @()
        foreach ($t in $terms) {
            $tt = $t.Trim()
            if ([string]::IsNullOrWhiteSpace($tt)) { continue }
            if ($tt -match '^([+-]?\d+(?:\.\d+)?)\s+(.+)$') {
                $out += ('{0} {1}' -f $matches[1], (Normalize-Species $matches[2]))
            } else {
                $out += (Normalize-Species $tt)
            }
        }
        return ($out -join ' + ')
    }
    $lhs = & $normSide $parts[0]
    $rhs = & $normSide $parts[1]
    return ('{0} = {1}' -f $lhs, $rhs)
}

function Canonical-SpeciesKey([string]$s) {
    if ($null -eq $s) { return '' }
    $x = Normalize-Species $s
    $x = $x -replace '\s+',''
    if ($x -match '^(.*?)(\+{2,})$') { return ($matches[1] + $matches[2].Length + '+') }
    if ($x -match '^(.*?)(-{2,})$') { return ($matches[1] + $matches[2].Length + '-') }
    if ($x -match '^(.*?)([+-])(\d+)$') { return ($matches[1] + $matches[3] + $matches[2]) }
    return $x
}

function Canonical-ProductKey([string]$s) {
    if ($null -eq $s) { return '' }
    $x = Normalize-Species $s
    $x = $x -replace '\s*\(aq\)\s*$',''
    return Canonical-SpeciesKey $x
}

function Parse-Double([string]$s) {
    $v = 0.0
    if ([double]::TryParse($s.Trim(), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)) {
        if ([double]::IsNaN($v) -or [double]::IsInfinity($v)) { return $null }
        return $v
    }
    return $null
}

function Make-Stoich-Signature($pairs) {
    $norm = @()
    foreach ($p in $pairs) {
        $norm += ('{0}|{1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $p.coeff)), (Canonical-SpeciesKey $p.species))
    }
    ($norm | Sort-Object) -join '; '
}

function Add-Record($sourceFamily, $sourceFile, $product, $pairs, $logk25, $referenceShort, $referenceDetail, $equationFull, [string]$dbComment = '', [string]$conditionKey = 'T=25C') {
    if ($null -eq $logk25) { return }
    $normProduct = Normalize-Species $product
    $normEq = Normalize-EquationDisplay $equationFull
    $refS = if ($null -eq $referenceShort) { '' } else { [string]$referenceShort }
    $refD = if ($null -eq $referenceDetail) { '' } else { [string]$referenceDetail }
    $dbc = if ($null -eq $dbComment) { '' } else { [string]$dbComment }
    $ck = if ($null -eq $conditionKey) { '' } else { [string]$conditionKey }
    $sig = ('{0}¦{1}¦{2}¦{3}¦{4}¦{5}¦{6}¦{7}¦{8}' -f
        $sourceFamily, $sourceFile, $normProduct, (Make-Stoich-Signature $pairs),
        [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###############}', [double]$logk25),
        $refS, $refD, $dbc, $ck
    )
    if (-not $recordSigSet.Add($sig)) { return }
    $rec = [PSCustomObject]@{
        source_family = $sourceFamily
        source_file = $sourceFile
        product = $normProduct
        equation_full = $normEq
        logK_definition = 'log10(K) at 25C for equation as written'
        stoich_signature = (Make-Stoich-Signature $pairs)
        logK_25C = $logk25
        reference_short = $referenceShort
        reference_detail = $referenceDetail
        db_comment = $dbComment
        condition_key = $conditionKey
    }
    $records.Add($rec)
}

function Build-ConditionKey([string]$temp, [string]$ionic, [string]$background, [string]$pressure, [string]$extra) {
    $parts = @()
    if (-not [string]::IsNullOrWhiteSpace($temp)) { $parts += ('T=' + $temp) } else { $parts += 'T=25C' }
    if (-not [string]::IsNullOrWhiteSpace($ionic)) { $parts += ('I=' + $ionic.Trim()) }
    if (-not [string]::IsNullOrWhiteSpace($background)) { $parts += ('BG=' + $background.Trim()) }
    if (-not [string]::IsNullOrWhiteSpace($pressure)) { $parts += ('P=' + $pressure.Trim()) }
    if (-not [string]::IsNullOrWhiteSpace($extra)) { $parts += ('EXTRA=' + $extra.Trim()) }
    return ($parts -join '; ')
}

function Load-Reference-Map($files) {
    $map = @{}
    foreach ($f in $files) {
        if (-not (Test-Path $f)) { continue }
        foreach ($line in Get-Content -Path $f) {
            if ($line.Trim().StartsWith('#')) { continue }
            if ($line -match '^([^=]+)=(.+)$') {
                $k = $matches[1].Trim()
                $v = $matches[2].Trim()
                if (-not [string]::IsNullOrWhiteSpace($k) -and -not $map.ContainsKey($k)) {
                    $map[$k] = $v
                }
            }
        }
    }
    return $map
}

function Expand-Reference-Codes([string]$shortRef, $refMap) {
    if ([string]::IsNullOrWhiteSpace($shortRef)) { return '' }
    $tokens = [regex]::Matches($shortRef, '[A-Za-z0-9][A-Za-z0-9\-\./]+') | ForEach-Object { $_.Value } | Select-Object -Unique
    $hits = @()
    foreach ($t in $tokens) {
        if ($refMap.ContainsKey($t)) {
            $hits += ('{0} = {1}' -f $t, $refMap[$t])
        }
    }
    return ($hits -join ' || ')
}

function Resolve-Reference-Codes([string]$text, $refMap, $refCatalog) {
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $tokens = @([regex]::Matches($text, '[0-9]{2}[A-Za-z]{3}(?:/[A-Za-z]{3})?') | ForEach-Object { $_.Value } | Select-Object -Unique)
    if ($tokens.Count -eq 0) { return '' }
    $out = @()
    foreach ($tok in $tokens) {
        $ltok = $tok.ToLowerInvariant()
        $found = $null
        if ($refMap.ContainsKey($tok)) { $found = $refMap[$tok] }
        elseif ($refMap.ContainsKey($ltok)) { $found = $refMap[$ltok] }
        if ($null -eq $found) {
            $yy = [int]$tok.Substring(0,2)
            $year = if ($yy -le 29) { 2000 + $yy } else { 1900 + $yy }
            $a1 = $tok.Substring(2,3).ToLowerInvariant()
            $a2 = if ($tok.Contains('/')) { $tok.Substring(6,3).ToLowerInvariant() } else { '' }
            $cands = @()
            if (-not [string]::IsNullOrWhiteSpace($a2)) {
                $cands = @($refCatalog | Where-Object {
                    $_.year -eq $year -and $_.textLower.Contains($a1) -and $_.textLower.Contains($a2)
                })
            }
            if ($cands.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($a2)) {
                $cands = @($refCatalog | Where-Object {
                    $_.year -eq $year -and ($_.textLower.Contains($a1) -or $_.textLower.Contains($a2))
                })
            }
            if ($cands.Count -eq 0) {
                $cands = @($refCatalog | Where-Object {
                    $_.year -eq $year -and $_.textLower.Contains($a1)
                })
            }
            if ($cands.Count -gt 0) { $found = $cands[0].text }
        }
        if (-not [string]::IsNullOrWhiteSpace($found)) { $out += $found }
    }
    return ($out | Select-Object -Unique) -join ' || '
}

function Clean-Reference-Text([string]$text) {
    if ([string]::IsNullOrWhiteSpace($text)) { return '' }
    $x = $text
    $x = [regex]::Replace($x, '\b[0-9]{2}[A-Za-z]{3}(?:/[A-Za-z]{3})?\b', '')
    $x = $x -replace '\s*[;|,]\s*', ' '
    $x = $x -replace '\s+', ' '
    return $x.Trim()
}

function Build-Consolidated-Reference([string]$shortRef, [string]$detailRef, $refMap, $refCatalog) {
    $s = if ($null -eq $shortRef) { '' } else { $shortRef.Trim() }
    $d = if ($null -eq $detailRef) { '' } else { $detailRef.Trim() }
    if ($s -like '*LLNL data source list at end of file*') { $s = '' }
    if ($d -like 'See "* Data sources, as cited by LLNL" section in file.*') { $d = '' }
    $resolvedFromS = Resolve-Reference-Codes $s $refMap $refCatalog
    $resolvedFromD = Resolve-Reference-Codes $d $refMap $refCatalog
    $parts = @()
    $sClean = Clean-Reference-Text $s
    $dClean = Clean-Reference-Text $d
    if (-not [string]::IsNullOrWhiteSpace($sClean)) { $parts += $sClean }
    if (-not [string]::IsNullOrWhiteSpace($dClean)) { $parts += $dClean }
    if (-not [string]::IsNullOrWhiteSpace($resolvedFromS)) { $parts += $resolvedFromS }
    if (-not [string]::IsNullOrWhiteSpace($resolvedFromD)) { $parts += $resolvedFromD }
    return ($parts | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join ' || '
}

function Extract-LLNLSourcesFromLines($lines) {
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\*\s*Data sources, as cited by LLNL:') { $start = $i + 1; break }
    }
    if ($start -lt 0) { return '' }
    $refs = @()
    $current = ''
    for ($i = $start; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ($ln -notmatch '^\*') { continue }
        $clean = ($ln -replace '^\*\s*','').Trim()
        if ([string]::IsNullOrWhiteSpace($clean)) {
            if (-not [string]::IsNullOrWhiteSpace($current)) {
                $refs += $current.Trim()
                $current = ''
            }
            continue
        }
        if ([string]::IsNullOrWhiteSpace($current)) { $current = $clean }
        else { $current += (' ' + $clean) }
    }
    if (-not [string]::IsNullOrWhiteSpace($current)) { $refs += $current.Trim() }
    if ($refs.Count -eq 0) { return '' }
    return ('LLNL cited sources: ' + (($refs | Select-Object -Unique) -join ' || '))
}

function Parse-GWBLike($filePath, $sourceFamily, $defaultRefShort, $defaultRefDetail) {
    $lines = Get-Content -Path $filePath
    $lastRef = $defaultRefShort
    $lastRefDetail = $defaultRefDetail
    $globalMeta = New-Object System.Collections.Generic.List[string]
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\*\s*(?!References?\s+DGf\s+or\s+LogK)(.+)$') {
            $metaTxt = $matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($metaTxt)) { $globalMeta.Add($metaTxt) | Out-Null }
        }
        if ($line -match '^\*\s*References?\s+DGf\s+or\s+LogK\s*(.+)$') {
            $lastRef = $matches[1].Trim()
            $lastRefDetail = ''
            continue
        }
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Trim().StartsWith('*')) { continue }
        if ($line.Trim().StartsWith('-end-')) { continue }
        if ($line -match '^\s*\d+\s+(elements|basis species|aqueous species|minerals|gases)') { continue }
        if ($line -match '^\S') {
            $product = $line.Trim()
            if ($i + 2 -ge $lines.Count) { continue }
            $j = $i + 1
            while ($j -lt $lines.Count -and -not ($lines[$j] -match 'species in reaction')) { $j++ }
            if ($j -ge $lines.Count) { continue }
            if ($lines[$j] -notmatch '(\d+)\s+species in reaction') { continue }
            $n = [int]$matches[1]
            $pairs = @()
            $j++
            while ($j -lt $lines.Count -and $pairs.Count -lt $n) {
                $l = $lines[$j]
                if ([string]::IsNullOrWhiteSpace($l)) { $j++; continue }
                if ($l -match '^\s*\*' -or $l -match '^\s*[a-f]\s*=' -or $l -match 'log10\s*K\(298\s*K\)') { break }
                $pm = [regex]::Matches($l, '([+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?)\s+(.+?)(?=\s+[+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?\s+|$)')
                foreach ($m in $pm) {
                    if ($pairs.Count -lt $n) {
                        $sp = $m.Groups[2].Value.Trim()
                        if ($sp -match '^[+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?$') { continue }
                        $pairs += [PSCustomObject]@{coeff = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture); species = $sp}
                    }
                }
                $j++
            }
            if ($pairs.Count -lt $n) { continue }
            $logvals = @()
            $explicitLogK = $null
            while ($j -lt $lines.Count) {
                $l = $lines[$j]
                if ([string]::IsNullOrWhiteSpace($l)) { $j++; continue }
                if ($l -match 'log10\s*K\(298\s*K\)\s*=\s*([+-]?(?:\d*\.\d+|\d+))') {
                    $explicitLogK = Parse-Double $matches[1]
                    $j++
                    continue
                }
                if ($l -match '^\s*\*\s*logK\s*=\s*([+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?)') {
                    $explicitLogK = Parse-Double $matches[1]
                    $j++
                    continue
                }
                if ($l -match '^\S' -or $l.Trim().StartsWith('-end-')) { break }
                if ($l.Trim().StartsWith('*')) { $j++; continue }
                $nm = [regex]::Matches($l, '[+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?')
                foreach ($m in $nm) {
                    $v = Parse-Double $m.Value
                    if ($null -ne $v) { $logvals += $v }
                }
                $j++
            }
            $logk25 = $null
            if ($null -ne $explicitLogK) { $logk25 = $explicitLogK }
            elseif ($logvals.Count -ge 2) { $logk25 = $logvals[1] }

            $speciesRef = $lastRef
            $speciesRefDetail = $lastRefDetail
            $localMeta = New-Object System.Collections.Generic.List[string]
            $k = $j
            while ($k -lt $lines.Count -and $lines[$k].Trim().StartsWith('*')) {
                $meta = $lines[$k]
                if ($meta -match 'reference-state data source\s*=\s*(.+)$') {
                    $speciesRef = $matches[1].Trim()
                    $speciesRefDetail = ''
                } elseif ($meta -match '^\*\s*References?\s+DGf\s+or\s+LogK\s*(.+)$') {
                    $speciesRef = $matches[1].Trim()
                    $speciesRefDetail = ''
                } elseif ($meta -match '^\*\s*(.+)$') {
                    $metaTxt = $matches[1].Trim()
                    if (-not [string]::IsNullOrWhiteSpace($metaTxt)) { $localMeta.Add($metaTxt) | Out-Null }
                }
                $k++
            }
            $j = $k

            # GWB-style databases store reactions/logK in dissociation convention:
            #   species = sum(basis species), with listed logK for this written reaction.
            # Normalize to formation convention (sum(basis) = species) by negating logK.
            $logk25 = if ($null -ne $logk25) { -1.0 * $logk25 } else { $null }
            $lhs = ($pairs | ForEach-Object { ('{0} {1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), (Normalize-Species $_.species)) }) -join ' + '
            $rxn = ('{0} = {1}' -f $lhs, (Normalize-Species $product))
            $dbComment = (@($localMeta) + @($globalMeta) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique) -join '; '
            Add-Record $sourceFamily $filePath $product $pairs $logk25 $speciesRef $speciesRefDetail $rxn $dbComment 'T=25C'
            $i = $j - 1
        }
    }
}

function Parse-SemicolonDB($filePath, $sourceFamily, $refMap) {
    foreach ($line in Get-Content -Path $filePath) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.Trim().StartsWith('#')) { continue }
        if (-not $line.Contains(';')) { continue }
        $parts = $line.Split(';')
        if ($parts.Count -lt 3) { continue }
        $product = $parts[0].Trim()
        if ($product -notmatch '[A-Za-z\(\)\[\]+-]') { continue }
        if ($product -match '^(NaN|[+-]?\d+(\.\d+)?)$') { continue }
        $logk25 = Parse-Double $parts[1]
        if ($null -eq $logk25) { continue }

        $hr = ''
        $hrIdx = -1
        for ($i = 0; $i -lt $parts.Count; $i++) {
            if ($parts[$i] -match '^\s*Hr\s*:') {
                $hr = ($parts[$i] -replace '^\s*Hr\s*:\s*','').Trim()
                $hrIdx = $i
                break
            }
        }
        if ($hrIdx -lt 0) { $hrIdx = $parts.Count }

        $pairs = @()
        for ($i = 2; $i -lt $hrIdx; $i++) {
            $nSpecies = 0
            if (-not [int]::TryParse($parts[$i].Trim(), [ref]$nSpecies)) { continue }
            if ($nSpecies -le 0) { continue }
            $end = $i + 1 + 2 * $nSpecies
            if ($end -gt $hrIdx) { continue }
            $candPairs = @()
            $ok = $true
            $idx = $i + 1
            for ($k = 0; $k -lt $nSpecies; $k++) {
                $sp = $parts[$idx].Trim()
                $cf = Parse-Double $parts[$idx + 1]
                if ([string]::IsNullOrWhiteSpace($sp) -or $null -eq $cf) { $ok = $false; break }
                if ($sp -match '^(analytic|lookUpTable)$') { $ok = $false; break }
                if ($sp -match '^[+-]?(?:\d*\.\d+|\d+)(?:[Ee][+-]?\d+)?$') { $ok = $false; break }
                if ($sp -notmatch '[A-Za-z\(\)\[\]]') { $ok = $false; break }
                $candPairs += [PSCustomObject]@{coeff = $cf; species = $sp}
                $idx += 2
            }
            if ($ok -and $candPairs.Count -eq $nSpecies) {
                $pairs = $candPairs
                break
            }
        }

        $detail = Expand-Reference-Codes $hr $refMap
        if ($pairs.Count -eq 0) { continue }
        $lhs = ($pairs | ForEach-Object { ('{0} {1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), (Normalize-Species $_.species)) }) -join ' + '
        $eqn = ('{0} = {1}' -f $lhs, (Normalize-Species $product))
        $fitType = ''
        if ($line -match ';(analytic|lookUpTable)(;|$)') { $fitType = $matches[1] }
        $dbCommentParts = @()
        if (-not [string]::IsNullOrWhiteSpace($fitType)) { $dbCommentParts += ('fit=' + $fitType) }
        if (-not [string]::IsNullOrWhiteSpace($hr)) { $dbCommentParts += ('Hr=' + $hr) }
        $dbComment = ($dbCommentParts -join '; ')
        Add-Record $sourceFamily $filePath $product $pairs $logk25 $hr $detail $eqn $dbComment 'T=25C'
    }
}

function Parse-QuotedThermoddem($filePath, $sourceFamily, $referenceText, [bool]$invertLogK = $false) {
    $lines = Get-Content -Path $filePath
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -notmatch "^'([^']+)'") { continue }
        $quoteCount = ([regex]::Matches($line, "'")).Count
        if ($quoteCount -lt 4) { continue }
        $product = $matches[1]
        $pairs = @()
        $pm = [regex]::Matches($line, '([+-]?\d*\.?\d+)\s+''([^'']+)''')
        foreach ($m in $pm) {
            $pairs += [PSCustomObject]@{coeff = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture); species = $m.Groups[2].Value}
        }
        if ($pairs.Count -eq 0) { continue }
        $logk25 = $null
        for ($j = $i + 1; $j -le [Math]::Min($i + 4, $lines.Count - 1); $j++) {
            if ($lines[$j] -match "^'" + [regex]::Escape($product) + "'") {
                $nums = [regex]::Matches($lines[$j], '[+-]?\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?') | ForEach-Object { Parse-Double $_.Value } | Where-Object { $null -ne $_ }
                if ($nums.Count -ge 8) { $logk25 = $nums[1]; break }
            }
        }
        if ($null -eq $logk25) { continue }
        if ($invertLogK) { $logk25 = -1.0 * $logk25 }
        $lhs = ($pairs | ForEach-Object { ('{0} {1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), (Normalize-Species $_.species)) }) -join ' + '
        $eqn = ('{0} = {1}' -f $lhs, (Normalize-Species $product))
        $dbComment = 'Exported Thermoddem format; references/conditions may be partially embedded.'
        Add-Record $sourceFamily $filePath $product $pairs $logk25 $referenceText '' $eqn $dbComment 'T=25C'
    }
}

function Normalize-EquilibriumExpr([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $x = $s.Trim()
    $x = $x -replace 'Â',''
    $x = $x -replace '²','2'
    $x = $x -replace '³','3'
    $x = $x -replace '¹','1'
    $x = $x -replace '⁰','0'
    $x = $x -replace '⁴','4'
    $x = $x -replace '⁵','5'
    $x = $x -replace '⁶','6'
    $x = $x -replace '⁷','7'
    $x = $x -replace '⁸','8'
    $x = $x -replace '⁹','9'
    $x = $x -replace '₀','0'
    $x = $x -replace '₁','1'
    $x = $x -replace '₂','2'
    $x = $x -replace '₃','3'
    $x = $x -replace '₄','4'
    $x = $x -replace '₅','5'
    $x = $x -replace '₆','6'
    $x = $x -replace '₇','7'
    $x = $x -replace '₈','8'
    $x = $x -replace '₉','9'
    return $x
}

function Parse-EquilibriumSide([string]$side) {
    $pairs = @()
    if ([string]::IsNullOrWhiteSpace($side)) { return $pairs }
    $m = [regex]::Matches($side, '\[([^\]]+)\](\d*)')
    foreach ($mm in $m) {
        $sp = $mm.Groups[1].Value.Trim()
        if ([string]::IsNullOrWhiteSpace($sp)) { continue }
        $coef = if ([string]::IsNullOrWhiteSpace($mm.Groups[2].Value)) { 1.0 } else { [double]$mm.Groups[2].Value }
        $pairs += [PSCustomObject]@{ coeff = $coef; species = $sp }
    }
    return $pairs
}

function Html-ToText([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return '' }
    $x = $s
    $x = [regex]::Replace($x, '(?i)<sub>\s*([^<]+)\s*</sub>', '$1')
    $x = [regex]::Replace($x, '(?i)<sup>\s*([^<]+)\s*</sup>', '$1')
    $x = [regex]::Replace($x, '(?i)<[^>]+>', '')
    return $x.Trim()
}

function Replace-NistPlaceholders([string]$token, [string]$metalToken, [string]$ligandToken) {
    $t = $token
    $t = $t -replace '\s+',''
    $t = $t -replace 'M', '§M§'
    $t = $t -replace 'L', '§L§'
    $t = $t -replace '§M§', "($metalToken)"
    $t = $t -replace '§L§', "($ligandToken)"
    if ($t -eq 'H') { return 'H+' }
    if ($t -eq 'OH') { return 'OH-' }
    return $t
}

function Load-TabIndex($path, [int]$keyIdx, [int]$valIdx) {
    $h = @{}
    if (-not (Test-Path $path)) { return $h }
    foreach ($ln in Get-Content -Path $path) {
        if ([string]::IsNullOrWhiteSpace($ln)) { continue }
        $p = $ln -split "`t"
        if ($p.Count -le [Math]::Max($keyIdx, $valIdx)) { continue }
        $k = $p[$keyIdx].Trim()
        if ([string]::IsNullOrWhiteSpace($k)) { continue }
        if (-not $h.ContainsKey($k)) { $h[$k] = $p[$valIdx].Trim() }
    }
    return $h
}

function Parse-NistSrd46Raw($sqlDir, $sourceFamily) {
    if (-not (Test-Path $sqlDir)) { return }
    $metalMap = Load-TabIndex (Join-Path $sqlDir 'metal.txt') 0 1
    $metalShortMap = Load-TabIndex (Join-Path $sqlDir 'metal.txt') 0 2
    $ligandMap = Load-TabIndex (Join-Path $sqlDir 'liganden.txt') 0 2
    $ligandNameMap = Load-TabIndex (Join-Path $sqlDir 'liganden.txt') 0 1
    $betaMap = Load-TabIndex (Join-Path $sqlDir 'beta_definition.txt') 0 1
    $litMap = @{}
    $litPath = Join-Path $sqlDir 'verkn_ligand_metal_literature_sic.txt'
    if (Test-Path $litPath) {
        foreach ($ln in Get-Content -Path $litPath) {
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            $p = $ln -split "`t"
            if ($p.Count -lt 4) { continue }
            $verknId = $p[1].Trim()
            $litId = $p[2].Trim()
            if (-not [string]::IsNullOrWhiteSpace($verknId) -and -not [string]::IsNullOrWhiteSpace($litId)) {
                if (-not $litMap.ContainsKey($verknId)) { $litMap[$verknId] = New-Object System.Collections.Generic.HashSet[string] }
                [void]$litMap[$verknId].Add($litId)
            }
        }
    }

    $verknPath = Join-Path $sqlDir 'verkn_ligand_metal_sic.txt'
    foreach ($ln in Get-Content -Path $verknPath) {
        if ([string]::IsNullOrWhiteSpace($ln)) { continue }
        $p = $ln -split "`t"
        if ($p.Count -lt 12) { continue }
        $verknId = $p[0].Trim()
        $ligId = $p[1].Trim()
        $metId = $p[2].Trim()
        $betaId = $p[3].Trim()
        $constType = $p[4].Trim()
        $temp = Parse-Double $p[5]
        $ionic = $p[6].Trim()
        $logk25 = Parse-Double $p[8]
        $errTxt = $p[9].Trim()
        $electrolyte = $p[12].Trim()
        $dbRowComment = $p[13].Trim()
        if ($constType -ne '3') { continue } # K constants only
        if ($null -eq $temp -or [Math]::Abs($temp - 25.0) -gt 1.0E-6) { continue }
        if ($null -eq $logk25) { continue }
        if (-not $betaMap.ContainsKey($betaId)) { continue }

        $metalName = if ($metalMap.ContainsKey($metId)) { Html-ToText $metalMap[$metId] } else { '' }
        $metalShort = if ($metalShortMap.ContainsKey($metId)) { Html-ToText $metalShortMap[$metId] } else { '' }
        $metalToken = ''
        if (-not [string]::IsNullOrWhiteSpace($metalName) -and -not [string]::IsNullOrWhiteSpace($metalShort)) {
            $metalToken = ('{0} ({1})' -f $metalName, $metalShort)
        } elseif (-not [string]::IsNullOrWhiteSpace($metalName)) {
            $metalToken = $metalName
        } elseif (-not [string]::IsNullOrWhiteSpace($metalShort)) {
            $metalToken = $metalShort
        } else {
            $metalToken = ('M' + $metId)
        }
        $ligFormula = if ($ligandMap.ContainsKey($ligId)) { Html-ToText $ligandMap[$ligId] } else { '' }
        $ligName = if ($ligandNameMap.ContainsKey($ligId)) { Html-ToText $ligandNameMap[$ligId] } else { '' }
        $ligandToken = ''
        if (-not [string]::IsNullOrWhiteSpace($ligName) -and -not [string]::IsNullOrWhiteSpace($ligFormula) -and $ligFormula -ne '********') {
            $ligandToken = ('{0} ({1})' -f $ligName, $ligFormula)
        } elseif (-not [string]::IsNullOrWhiteSpace($ligName)) {
            $ligandToken = $ligName
        } elseif (-not [string]::IsNullOrWhiteSpace($ligFormula) -and $ligFormula -ne '********') {
            $ligandToken = $ligFormula
        } else {
            $ligandToken = ('L' + $ligId)
        }
        $eqRaw = Normalize-EquilibriumExpr (Html-ToText $betaMap[$betaId])
        if (-not $eqRaw.Contains('/')) { continue }
        $parts = $eqRaw.Split('/')
        if ($parts.Count -ne 2) { continue }
        $numPairs = @(Parse-EquilibriumSide $parts[0])
        $denPairs = @(Parse-EquilibriumSide $parts[1])
        if ($numPairs.Count -eq 0 -or $denPairs.Count -eq 0) { continue }

        $numPairs = @($numPairs | ForEach-Object { [PSCustomObject]@{ coeff = $_.coeff; species = (Replace-NistPlaceholders $_.species $metalToken $ligandToken) } })
        $denPairs = @($denPairs | ForEach-Object { [PSCustomObject]@{ coeff = $_.coeff; species = (Replace-NistPlaceholders $_.species $metalToken $ligandToken) } })
        $prod = ($numPairs | ForEach-Object {
            if ([Math]::Abs($_.coeff - 1.0) -lt 1.0E-12) { $_.species } else { ('{0}{1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), $_.species) }
        }) -join ' + '
        $lhs = ($denPairs | ForEach-Object {
            ('{0} {1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), (Normalize-Species $_.species))
        }) -join ' + '
        $eqn = ('{0} = {1}' -f $lhs, (Normalize-Species $prod))
        $litRef = ''
        if ($litMap.ContainsKey($verknId)) { $litRef = (' literature_ids=' + (($litMap[$verknId] | Sort-Object) -join ',')) }
        $ref = ('NIST SRD 46 raw SQL; beta_definition_id={0}; ligand_id={1}; ligand_name={2}; metal_id={3}; metal={4}{5}' -f $betaId, $ligId, $ligName, $metId, $metalName, $litRef)
        $dbCommentParts = @()
        if (-not [string]::IsNullOrWhiteSpace($ionic)) { $dbCommentParts += ('I=' + $ionic) }
        if (-not [string]::IsNullOrWhiteSpace($errTxt) -and $errTxt -ne '\N') { $dbCommentParts += ('uncertainty=' + $errTxt) }
        if (-not [string]::IsNullOrWhiteSpace($electrolyte) -and $electrolyte -ne '\N') { $dbCommentParts += ('electrolyte=' + $electrolyte) }
        if (-not [string]::IsNullOrWhiteSpace($dbRowComment) -and $dbRowComment -ne '\N') { $dbCommentParts += ('comment=' + $dbRowComment) }
        $dbComment = ($dbCommentParts -join '; ')
        $cond = Build-ConditionKey '25C' $ionic $electrolyte '' ''
        Add-Record $sourceFamily $verknPath $prod $denPairs $logk25 $ref '' $eqn $dbComment $cond
    }
}

function Parse-IupacPka($csvPath, $sourceFamily) {
    if (-not (Test-Path $csvPath)) { return }
    foreach ($r in Import-Csv -Path $csvPath) {
        $temp = Parse-Double ([string]$r.T)
        if ($null -eq $temp -or [Math]::Abs($temp - 25.0) -gt 1.0E-6) { continue }
        $logk = Parse-Double ([string]$r.pka_value)
        if ($null -eq $logk) { continue }
        $pkType = ([string]$r.pka_type).Trim()
        $uid = ([string]$r.unique_ID).Trim()
        if ([string]::IsNullOrWhiteSpace($uid)) { continue }
        $name = ([string]$r.original_IUPAC_names).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { $name = ([string]$r.original_IUPAC_nicknames).Trim() }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = $uid }
        $name = $name -replace '\s+',' '
        $pairs = @()
        $eqn = ''
        $product = ''
        if ($pkType -match '^pKaH') {
            $pairs = @([PSCustomObject]@{coeff=1.0; species=("$name (base)")}, [PSCustomObject]@{coeff=1.0; species='H+'})
            $product = "$name (conjugate acid)"
            $eqn = ("1 {0} (base) + 1 H+ = 1 {0} (conjugate acid)" -f $name)
        } elseif ($pkType -match '^pKa') {
            $pairs = @([PSCustomObject]@{coeff=1.0; species=("$name (deprotonated)")}, [PSCustomObject]@{coeff=1.0; species='H+'})
            $product = "$name (protonated)"
            $eqn = ("1 {0} (deprotonated) + 1 H+ = 1 {0} (protonated)" -f $name)
        } elseif ($pkType -match '^pKb') {
            $pairs = @([PSCustomObject]@{coeff=1.0; species=("$name (base)")}, [PSCustomObject]@{coeff=1.0; species='H2O'})
            $product = "$name (conjugate acid) + OH-"
            $eqn = ("1 {0} (base) + 1 H2O = 1 {0} (conjugate acid) + 1 OH-" -f $name)
        } else {
            $pairs = @([PSCustomObject]@{coeff=1.0; species=("$name (unspecified state)")})
            $product = "$name (pK type $pkType)"
            $eqn = ('1 {0} (unspecified state) = 1 {0} (pK type {1})' -f $name, $pkType)
        }
        $ref = ('IUPAC Digitized pKa Dataset v2.3d; ref=' + ([string]$r.ref) + '; unique_ID=' + $uid)
        $detail = ([string]$r.ref_remarks).Trim()
        if ([string]::IsNullOrWhiteSpace($detail)) { $detail = ([string]$r.entry_remarks).Trim() }
        $dbCommentParts = @()
        $remarks = ([string]$r.remarks).Trim()
        $method = ([string]$r.method).Trim()
        $assessment = ([string]$r.assessment).Trim()
        $pressure = ([string]$r.pressure).Trim()
        if (-not [string]::IsNullOrWhiteSpace($remarks)) { $dbCommentParts += ('remarks=' + $remarks) }
        if (-not [string]::IsNullOrWhiteSpace($method)) { $dbCommentParts += ('method=' + $method) }
        if (-not [string]::IsNullOrWhiteSpace($assessment)) { $dbCommentParts += ('assessment=' + $assessment) }
        if (-not [string]::IsNullOrWhiteSpace($pressure)) { $dbCommentParts += ('pressure=' + $pressure) }
        $dbComment = ($dbCommentParts -join '; ')
        $ionic = ''
        $background = ''
        if ($remarks -match '(?i)\bI\s*=\s*([^;,\)\]]+)') { $ionic = $matches[1].Trim() }
        if ($remarks -match '(?i)\b(?:in|with)\s+([A-Za-z0-9\(\)\+\-\s]{2,20})\s*(?:solution|medium|electrolyte)') { $background = $matches[1].Trim() }
        $cond = Build-ConditionKey '25C' $ionic $background $pressure ''
        Add-Record $sourceFamily $csvPath $product $pairs $logk $ref $detail $eqn $dbComment $cond
    }
}

function Parse-AqSolDB($csvPath, $sourceFamily) {
    if (-not (Test-Path $csvPath)) { return }
    foreach ($r in Import-Csv -Path $csvPath) {
        $logS = Parse-Double ([string]$r.Solubility)
        if ($null -eq $logS) { continue }
        $name = ([string]$r.Name).Trim()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $product = "$name (aq)"
        $solid = "$name (s)"
        $pairs = @([PSCustomObject]@{coeff=1.0; species=$solid})
        $eqn = ("1 {0} = 1 {1}" -f $solid, $product)
        $ref = 'AqSolDB curated aqueous solubility dataset; Sorkun et al., Sci Data (2019), doi:10.1038/s41597-019-0151-1'
        $dbCommentParts = @('AqSolDB logS value used as solubility-proxy; not a direct thermodynamic equilibrium constant')
        if (-not [string]::IsNullOrWhiteSpace([string]$r.ID)) { $dbCommentParts += ('ID=' + [string]$r.ID) }
        if (-not [string]::IsNullOrWhiteSpace([string]$r.InChIKey)) { $dbCommentParts += ('InChIKey=' + [string]$r.InChIKey) }
        if (-not [string]::IsNullOrWhiteSpace([string]$r.SMILES)) { $dbCommentParts += ('SMILES=' + [string]$r.SMILES) }
        if (-not [string]::IsNullOrWhiteSpace([string]$r.SD)) { $dbCommentParts += ('SD=' + [string]$r.SD) }
        if (-not [string]::IsNullOrWhiteSpace([string]$r.Occurrences)) { $dbCommentParts += ('Occurrences=' + [string]$r.Occurrences) }
        if (-not [string]::IsNullOrWhiteSpace([string]$r.Group)) { $dbCommentParts += ('Group=' + [string]$r.Group) }
        $dbComment = ($dbCommentParts -join '; ')
        $cond = Build-ConditionKey '' '' '' '' 'AqSolDB logS (temperature/ionic strength not specified)'
        Add-Record $sourceFamily $csvPath $product $pairs $logS $ref '' $eqn $dbComment $cond
    }
}

function Simplify-SourcePath([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return '' }
    $x = $p -replace '/','\'
    $parts = $x.Split('\')
    $idx = [Array]::IndexOf($parts, 'External databases')
    $file = $parts[$parts.Length - 1]
    if ($idx -ge 0 -and $idx + 1 -lt $parts.Length) {
        $folder = $parts[$idx + 1]
        return ('{0}\{1}' -f $folder, $file)
    }
    return $file
}

function Get-DatabaseNameFromPath([string]$p) {
    if ([string]::IsNullOrWhiteSpace($p)) { return '' }
    $leaf = Split-Path -Leaf $p
    if ([string]::IsNullOrWhiteSpace($leaf)) { return '' }
    return [System.IO.Path]::GetFileNameWithoutExtension($leaf)
}

function Build-ContributingSourceLabel($rec) {
    $family = [string]$rec.source_family
    if ($family -eq 'MedusaText') { $family = 'Medusa' }
    $dbName = Get-DatabaseNameFromPath ([string]$rec.source_file)
    if ([string]::IsNullOrWhiteSpace($dbName)) { return $family }
    return ('{0}-{1}' -f $family, $dbName)
}

function Parse-Phreeqc($filePath, $sourceFamily) {
    function Parse-PhreeqcSide([string]$sideText) {
        $out = @()
        if ([string]::IsNullOrWhiteSpace($sideText)) { return $out }
        $terms = $sideText -split '\s+\+\s+'
        foreach ($t in $terms) {
            $term = $t.Trim()
            if ([string]::IsNullOrWhiteSpace($term)) { continue }
            $coef = 1.0
            $spec = $term
            if ($term -match '^\s*([+-]?(?:\d*\.?\d+(?:[Ee][+-]?\d+)?))\s+(.+?)\s*$') {
                $coef = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                $spec = $matches[2].Trim()
            } elseif ($term -match '^\s*([+-]?(?:\d*\.?\d+(?:[Ee][+-]?\d+)?))([A-Za-z].+?)\s*$') {
                $coef = [double]::Parse($matches[1], [System.Globalization.CultureInfo]::InvariantCulture)
                $spec = $matches[2].Trim()
            }
            if (-not [string]::IsNullOrWhiteSpace($spec)) {
                $out += [PSCustomObject]@{ coeff = $coef; species = $spec }
            }
        }
        return $out
    }

    $lines = Get-Content -Path $filePath
    $inSection = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd()
        if ($line -match '^(SOLUTION_SPECIES|PHASES)$') { $inSection = $true; continue }
        if ($line -match '^[A-Z_]+$' -and $line -notmatch '^(SOLUTION_SPECIES|PHASES)$') { $inSection = $false }
        if (-not $inSection) { continue }
        if ($line.Trim().StartsWith('#')) { continue }
        if ($line -notmatch '=') { continue }

        $eq = $line.Trim()
        $parts = $eq -split '='
        if ($parts.Count -ne 2) { continue }
        $lhs = $parts[0].Trim()
        $rhs = $parts[1].Trim()
        if ([string]::IsNullOrWhiteSpace($rhs)) { continue }

        $product = $rhs
        $pairs = @(Parse-PhreeqcSide $lhs)

        $logk25 = $null
        $ref = ''
        $commentBits = New-Object System.Collections.Generic.List[string]
        for ($j = $i + 1; $j -le [Math]::Min($i + 12, $lines.Count - 1); $j++) {
            $l2 = $lines[$j].Trim()
            if ($l2 -match '^-?log_k\s+([+-]?\d+(?:\.\d+)?)') {
                $logk25 = Parse-Double $matches[1]
                if ($l2 -match '#\s*(.+)$') {
                    $cmtInline = $matches[1].Trim()
                    if (-not [string]::IsNullOrWhiteSpace($cmtInline)) { $commentBits.Add($cmtInline) | Out-Null }
                }
            }
            if ($l2 -match '^#References\s*=\s*(.+)$') {
                $ref = $matches[1].Trim()
            } elseif ($l2 -match '^#\s*(.+)$') {
                $cmt = $matches[1].Trim()
                if (-not [string]::IsNullOrWhiteSpace($cmt)) { $commentBits.Add($cmt) | Out-Null }
            }
            if ($l2 -match '^$') { break }
        }
        if ($null -eq $logk25 -or $pairs.Count -eq 0) { continue }
        $dbComment = ($commentBits | Select-Object -Unique) -join '; '
        Add-Record $sourceFamily $filePath $product $pairs $logk25 $ref '' $eq $dbComment 'T=25C'
    }
}

function Parse-Chess($filePath, $sourceFamily, $referenceText) {
    $lines = Get-Content -Path $filePath
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*([^#\s][^\{]*)\{\s*$') {
            $name = $matches[1].Trim()
            if ($name -in @('comment','basis-species','redox-couples','aqueous-species','minerals','gases')) { continue }
            $comp = ''
            $logText = ''
            $j = $i + 1
            while ($j -lt $lines.Count -and $lines[$j] -notmatch '^\s*}\s*$') {
                $ln = $lines[$j].Trim()
                if ($ln -match '^composition\s*=\s*(.+)$') { $comp = $matches[1] }
                if ($ln -match '^logK\s*=\s*(.+)$') {
                    $logText = $matches[1]
                    while ($j + 1 -lt $lines.Count -and $lines[$j].TrimEnd().EndsWith('\\')) {
                        $j++
                        $logText += ' ' + $lines[$j].Trim()
                    }
                }
                $j++
            }
            if ([string]::IsNullOrWhiteSpace($comp) -or [string]::IsNullOrWhiteSpace($logText)) { continue }
            $m25 = [regex]::Match($logText, '([+-]?\d+(?:\.\d+)?)\(25\)')
            if (-not $m25.Success) { continue }
            $logk25 = Parse-Double $m25.Groups[1].Value
            $pairs = @()
            $cm = [regex]::Matches($comp, '([+-]?\d*\.?\d+)\s+([^,]+)')
            foreach ($m in $cm) {
                $pairs += [PSCustomObject]@{coeff = [double]::Parse($m.Groups[1].Value, [System.Globalization.CultureInfo]::InvariantCulture); species = $m.Groups[2].Value.Trim()}
            }
            if ($pairs.Count -eq 0) { continue }
            $lhs = ($pairs | ForEach-Object { ('{0} {1}' -f ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.###}', $_.coeff)), (Normalize-Species $_.species)) }) -join ' + '
            $eqn = ('{0} = {1}' -f $lhs, (Normalize-Species $name))
            $dbComment = 'CHESS TDB export; logK(T) polynomial sampled at 25C.'
            Add-Record $sourceFamily $filePath $name $pairs $logk25 $referenceText '' $eqn $dbComment 'T=25C'
        }
    }
}

function Is-SimilarLogK([double]$a, [double]$b) {
    $scale = [Math]::Max([Math]::Abs($a), [Math]::Abs($b))
    if ($scale -lt 1.0E-6) { return ([Math]::Abs($a - $b) -le 5.0E-8) }
    return ([Math]::Abs($a - $b) -le 0.05 * $scale)
}

$refMap = Load-Reference-Map @(
    (Join-Path $root 'External databases\Medusa\References.txt'),
    (Join-Path $root 'External databases\Medusa\Soltherm_References.txt'),
    (Join-Path $root 'External databases\Medusa\MintEQ-v4_References.txt'),
    (Join-Path $root 'External databases\Medusa\Wateq4F_References.txt'),
    (Join-Path $root 'External databases\Medusa\Medusa-Hydra_References.txt')
)
$refCatalog = @()
foreach ($k in $refMap.Keys) {
    $txt = [string]$refMap[$k]
    $mYear = [regex]::Match($txt, '(19|20)\d{2}')
    $yr = if ($mYear.Success) { [int]$mYear.Value } else { -1 }
    $refCatalog += [PSCustomObject]@{
        key = $k
        text = $txt
        textLower = $txt.ToLowerInvariant()
        year = $yr
    }
}

# GWB .tdat files
Get-ChildItem -Path (Join-Path $root 'External databases\GWB') -Filter *.tdat | ForEach-Object {
    Parse-GWBLike $_.FullName 'GWB' '' ''
}

# Medusa semicolon text databases
$medusaTxt = @(
    (Join-Path $root 'External databases\Medusa\Soltherm.txt'),
    (Join-Path $root 'External databases\Medusa\PHREEQC_ThermoddemV1.10_15Dec2020.txt')
)
foreach ($f in $medusaTxt) {
    if (Test-Path $f) { Parse-SemicolonDB $f 'MedusaText' $refMap }
}

# Thermoddem converted formats
$gwbThermo = Join-Path $root 'External databases\Thermoddem\unzipped\gwb_thermoddemv1.10_15dec2020\GWB_ThermoddemV1.10_15Dec2020.dat'
if (Test-Path $gwbThermo) { Parse-GWBLike $gwbThermo 'Thermoddem-GWB' 'Inline "References DGf or LogK ..." comment in file' '' }

$phreeqcThermo = Join-Path $root 'External databases\Thermoddem\unzipped\phreeqc_thermoddemv1.10_15dec2020(1)\PHREEQC_ThermoddemV1.10_15Dec2020.dat'
if (Test-Path $phreeqcThermo) { Parse-Phreeqc $phreeqcThermo 'Thermoddem-PHREEQC' }

$psiNagraPhreeqc = Join-Path $root 'External databases\TDB\psinagra2020_v2-1-phreeqc\psinagra2020_v2-1ext.dat'
if (Test-Path $psiNagraPhreeqc) { Parse-Phreeqc $psiNagraPhreeqc 'PSINagra-PHREEQC' }

$jessPhreeqcLike = Join-Path $root 'outputs\jess_phreeqc_like.dat'
if (Test-Path $jessPhreeqcLike) { Parse-Phreeqc $jessPhreeqcLike 'JESS-PHREEQC-like' }

$crunchThermo = Join-Path $root 'External databases\Thermoddem\unzipped\crunch_thermoddemv1.10_15dec2020\Crunch_ThermoddemV1.10_15Dec2020.dbs'
if (Test-Path $crunchThermo) { Parse-QuotedThermoddem $crunchThermo 'Thermoddem-Crunch' 'Reference not embedded in this export format' $false }

$toughThermo = Join-Path $root 'External databases\Thermoddem\unzipped\toughreact_thermoddemv1.10_15dec2020\ToughReact_ThermoddemV1.10_15Dec2020.dat'
if (Test-Path $toughThermo) { Parse-QuotedThermoddem $toughThermo 'Thermoddem-ToughReact' 'Reference not embedded in this export format' $true }

$chessThermo = Join-Path $root 'External databases\Thermoddem\unzipped\chess_thermoddemv1.10_15dec2020(1)\Chess_ThermoddemV1.10_15Dec2020.tdb'
if (Test-Path $chessThermo) { Parse-Chess $chessThermo 'Thermoddem-CHESS' 'Reference not embedded in this export format' }

# NIST SRD 46 text extraction (25C LogK entries)
$nistSql = Join-Path $root 'External databases\NIST SRD 46\SRD 46 SQL'
if (Test-Path $nistSql) { Parse-NistSrd46Raw $nistSql 'NIST-SRD46' }

# IUPAC Dissociation Constants (25C pKa values)
$iupacCsv = Join-Path $root 'External databases\IUPAC Dissociation Constants\iupac_high-confidence_v2_3.csv'
if (Test-Path $iupacCsv) { Parse-IupacPka $iupacCsv 'IUPAC-pKa' }

# AqSolDB curated aqueous solubility dataset
$aqsolCsv = Join-Path $root 'External databases\AqSolDB\results\data_curated.csv'
if (Test-Path $aqsolCsv) { Parse-AqSolDB $aqsolCsv 'AqSolDB-logS' }

# Merge near-identical logK values (<=5% relative deviation) for same product key + stoichiometry + conditions
$grouped = $records | Group-Object { '{0}|{1}|{2}' -f (Canonical-ProductKey $_.product), $_.stoich_signature, $_.condition_key }
$finalRows = New-Object System.Collections.Generic.List[object]
foreach ($g in $grouped) {
    $clusters = @()
    $entries = $g.Group | Sort-Object logK_25C
    foreach ($r in $entries) {
        $assigned = $false
        foreach ($c in $clusters) {
            if (Is-SimilarLogK ([double]$r.logK_25C) ([double]$c.mean)) {
                $c.items.Add($r) | Out-Null
                $vals = $c.items | ForEach-Object { [double]$_.logK_25C }
                $c.mean = ($vals | Measure-Object -Average).Average
                $assigned = $true
                break
            }
        }
        if (-not $assigned) {
            $clusters += [PSCustomObject]@{
                mean = [double]$r.logK_25C
                items = (New-Object System.Collections.Generic.List[object])
            }
            $clusters[-1].items.Add($r) | Out-Null
        }
    }

    foreach ($c in $clusters) {
        $items = $c.items
        $rep = $items[0]
        $srcDb = New-Object System.Collections.Generic.HashSet[string]
        $srcFiles = New-Object System.Collections.Generic.HashSet[string]
        $refs = New-Object System.Collections.Generic.HashSet[string]
        $dbComments = New-Object System.Collections.Generic.HashSet[string]
        $conds = New-Object System.Collections.Generic.HashSet[string]
        $vals = @()
        foreach ($it in $items) {
            [void]$srcDb.Add($it.source_family)
            [void]$srcFiles.Add((Simplify-SourcePath $it.source_file))
            $rr = Build-Consolidated-Reference $it.reference_short $it.reference_detail $refMap $refCatalog
            if (-not [string]::IsNullOrWhiteSpace($rr)) { [void]$refs.Add($rr) }
            if (-not [string]::IsNullOrWhiteSpace($it.db_comment)) { [void]$dbComments.Add($it.db_comment) }
            if (-not [string]::IsNullOrWhiteSpace($it.condition_key)) { [void]$conds.Add($it.condition_key) }
            $vals += [string]::Format(
                [System.Globalization.CultureInfo]::InvariantCulture,
                '{0:0.#########} ({1})',
                [double]$it.logK_25C,
                (Build-ContributingSourceLabel $it)
            )
        }
        $refText = ($refs | Sort-Object) -join ' || '
        if ([string]::IsNullOrWhiteSpace($refText)) { $refText = 'Source not explicitly specified in this database file' }
        $finalRows.Add([PSCustomObject]@{
            product = $rep.product
            equation_full = $rep.equation_full
            logK = [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0:0.#########}', [double]$c.mean)
            contributing_logK = ($vals -join ' | ')
            experimental_conditions = (($conds | Sort-Object) -join ' || ')
            reference_consolidated = $refText
            database_comments = (($dbComments | Sort-Object) -join ' || ')
        }) | Out-Null
    }
}

$finalNoDup = New-Object System.Collections.Generic.List[object]
$finalSig = New-Object System.Collections.Generic.HashSet[string]
foreach ($r in $finalRows) {
    $s = ('{0}¦{1}¦{2}¦{3}¦{4}¦{5}¦{6}' -f
        ([string]$r.product), ([string]$r.equation_full), ([string]$r.logK),
        ([string]$r.contributing_logK), ([string]$r.experimental_conditions),
        ([string]$r.database_comments), ([string]$r.reference_consolidated)
    )
    if ($finalSig.Add($s)) { $finalNoDup.Add($r) | Out-Null }
}

$final = $finalNoDup | Sort-Object product, {[double]$_.logK}

$tsvPath = Join-Path $outDir 'thermo_equilibrium_merged.tsv'
$final | Export-Csv -Path $tsvPath -Delimiter "`t" -NoTypeInformation -Encoding UTF8

$summaryBySource = $records | Group-Object source_family | Sort-Object Name
$mergedCount = $final.Count
$rawCount = $records.Count

$missing = @(
    'External databases\\Medusa\\*.db and *.elb (binary format, no built-in parser in this extraction)',
    'External databases\\NIST SRD 46\\NIST_SRD_46_ported.db (file content is HTML, not a thermodynamic DB; using SRD 46 SQL raw dump instead)'
)

$mdPath = Join-Path $outDir 'thermo_equilibrium_report.md'
$md = New-Object System.Text.StringBuilder
[void]$md.AppendLine('# Thermodynamic Equilibrium Extraction Report')
[void]$md.AppendLine('')
[void]$md.AppendLine('## Output Files')
[void]$md.AppendLine(('- Full merged table: `{0}`' -f $tsvPath))
[void]$md.AppendLine('')
[void]$md.AppendLine('## Extraction Statistics')
[void]$md.AppendLine(('- Raw extracted records: **{0}**' -f $rawCount))
[void]$md.AppendLine(('- Merged unique records: **{0}**' -f $mergedCount))
[void]$md.AppendLine('')
[void]$md.AppendLine('### Records By Source Family')
foreach ($g in $summaryBySource) {
    [void]$md.AppendLine(('- `{0}`: {1}' -f $g.Name, $g.Count))
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## Databases That Could Not Be Fully Parsed')
foreach ($m in $missing) {
    [void]$md.AppendLine(('- {0}' -f $m))
}
[void]$md.AppendLine('')
[void]$md.AppendLine('## Notes On Merging')
[void]$md.AppendLine('- Rows are grouped by product + stoichiometric signature + experimental conditions, then logK values within 5% relative deviation are merged.')
[void]$md.AppendLine('- Product labels with or without explicit `(aq)` are treated as the same product key for merging.')
[void]$md.AppendLine('- For each merged row, logK is the arithmetic average of contributing values.')
[void]$md.AppendLine('- Contributing source labels are preserved in `contributing_logK` as `Family-DatabaseName`.')
[System.IO.File]::WriteAllText($mdPath, $md.ToString(), [System.Text.Encoding]::UTF8)

# Searchable HTML report
$htmlPath = Join-Path $outDir 'thermo_equilibrium_report.html'
$jsonData = ($final | ConvertTo-Json -Depth 6 -Compress)
$jsonData = $jsonData -replace '</script>', '<\/script>'
$html = @'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>logK25 database</title>
  <style>
    :root { --bg:#f7f8fa; --fg:#1f2937; --muted:#6b7280; --line:#d1d5db; --card:#ffffff; --accent:#0f766e; }
    body { margin:0; font-family: "Segoe UI", Tahoma, sans-serif; background:var(--bg); color:var(--fg); }
    .wrap { max-width: 1800px; margin: 0 auto; padding: 16px; }
    h1 { margin: 0 0 10px; font-size: 22px; }
    .meta { color: var(--muted); margin-bottom: 12px; }
    .bar { margin-bottom:12px; }
    .periodic { display:grid; grid-template-columns: repeat(18, minmax(30px, 1fr)); gap:4px; border:1px solid var(--line); padding:8px; border-radius:10px; background:#f0fdfa; }
    .el-btn { border:1px solid #99f6e4; background:#ffffff; color:#134e4a; border-radius:6px; font-size:11px; padding:6px 0; cursor:pointer; }
    .el-btn:hover { background:#ccfbf1; }
    .el-btn.sel { background:#0f766e; color:#ffffff; border-color:#0f766e; }
    .periodic-spacer { min-height:30px; }
    .periodic-note { color:var(--muted); font-size:12px; margin:6px 0 0; }
    .table-wrap { border:1px solid var(--line); border-radius: 10px; background:var(--card); overflow:auto; max-height: 75vh; }
    table { border-collapse: collapse; width: 100%; min-width: 1400px; }
    th, td { border-bottom:1px solid #e5e7eb; padding: 8px 10px; text-align:left; vertical-align: top; font-size: 12px; }
    th { position: sticky; top: 0; background: #ecfeff; cursor: pointer; user-select: none; }
    tr:hover td { background:#f9fafb; }
    .mono { font-family: Consolas, "Courier New", monospace; font-size: 11.5px; }
    .pill { display:inline-block; padding:2px 8px; border-radius: 999px; background:#ccfbf1; color:#115e59; }
  </style>
</head>
<body>
  <div class="wrap">
    <h1>logK25 database</h1>
    <div class="meta">
      <span class="pill">Rows: <span id="count">0</span></span>
    </div>
    <div class="bar">
      <div id="periodic" class="periodic" title="Click atoms to filter rows"></div>
      <div class="periodic-note">Click atoms to filter rows containing all selected atoms.</div>
    </div>
    <div class="table-wrap">
      <table id="tbl">
        <thead>
          <tr>
            <th data-k="product">Product</th>
            <th data-k="equation_full">Equation (as written)</th>
            <th data-k="logK">logK</th>
            <th data-k="contributing_logK">Contributing logK</th>
            <th data-k="experimental_conditions">Experimental conditions</th>
            <th data-k="database_comments">Database comments</th>
            <th data-k="reference_consolidated">Reference (consolidated)</th>
          </tr>
        </thead>
        <tbody></tbody>
      </table>
    </div>
  </div>
  <script>
    const data = __JSON_DATA__;
    const periodicAtoms = ["Ac","Ag","Al","Am","Ar","As","At","Au","B","Ba","Be","Bh","Bi","Bk","Br","C","Ca","Cd","Ce","Cf","Cl","Cm","Cn","Co","Cr","Cs","Cu","Db","Ds","Dy","Er","Es","Eu","F","Fe","Fl","Fm","Fr","Ga","Gd","Ge","H","He","Hf","Hg","Ho","Hs","I","In","Ir","K","Kr","La","Li","Lr","Lu","Lv","Mc","Md","Mg","Mn","Mo","Mt","N","Na","Nb","Nd","Ne","Nh","Ni","No","Np","O","Og","Os","P","Pa","Pb","Pd","Pm","Po","Pr","Pt","Pu","Ra","Rb","Re","Rf","Rg","Rh","Rn","Ru","S","Sb","Sc","Se","Sg","Si","Sm","Sn","Sr","Ta","Tb","Tc","Te","Th","Ti","Tl","Tm","Ts","U","V","W","Xe","Y","Yb","Zn","Zr"];
    const periodicSet = new Set(periodicAtoms);
    const periodic = document.getElementById('periodic');
    const tbody = document.querySelector('#tbl tbody');
    const count = document.getElementById('count');
    const headers = [...document.querySelectorAll('th[data-k]')];
    let sortKey = 'product';
    let sortAsc = true;
    const selectedAtoms = new Set();

    const periodicGrid = [
      ["H","","","","","","","","","","","","","","","","","He"],
      ["Li","Be","","","","","","","","","","","B","C","N","O","F","Ne"],
      ["Na","Mg","","","","","","","","","","","Al","Si","P","S","Cl","Ar"],
      ["K","Ca","Sc","Ti","V","Cr","Mn","Fe","Co","Ni","Cu","Zn","Ga","Ge","As","Se","Br","Kr"],
      ["Rb","Sr","Y","Zr","Nb","Mo","Tc","Ru","Rh","Pd","Ag","Cd","In","Sn","Sb","Te","I","Xe"],
      ["Cs","Ba","La","Hf","Ta","W","Re","Os","Ir","Pt","Au","Hg","Tl","Pb","Bi","Po","At","Rn"],
      ["Fr","Ra","Ac","Rf","Db","Sg","Bh","Hs","Mt","Ds","Rg","Cn","Nh","Fl","Mc","Lv","Ts","Og"],
      ["","","La","Ce","Pr","Nd","Pm","Sm","Eu","Gd","Tb","Dy","Ho","Er","Tm","Yb","Lu",""],
      ["","","Ac","Th","Pa","U","Np","Pu","Am","Cm","Bk","Cf","Es","Fm","Md","No","Lr",""]
    ];

    periodicGrid.forEach(row => {
      row.forEach(sym => {
        if (!sym) {
          const sp = document.createElement('div');
          sp.className = 'periodic-spacer';
          periodic.appendChild(sp);
          return;
        }
        const b = document.createElement('button');
        b.type = 'button';
        b.className = 'el-btn';
        b.textContent = sym;
        b.dataset.atom = sym;
        b.addEventListener('click', () => {
          if (selectedAtoms.has(sym)) {
            selectedAtoms.delete(sym);
            b.classList.remove('sel');
          } else {
            selectedAtoms.add(sym);
            b.classList.add('sel');
          }
          render();
        });
        periodic.appendChild(b);
      });
    });

    function toNum(v) { const n = Number(v); return Number.isFinite(n) ? n : null; }
    function extractAtomsFromText(txt){
      const m = (txt || '').match(/[A-Z][a-z]?/g) || [];
      const out = new Set();
      m.forEach(x => { if (periodicSet.has(x)) out.add(x); });
      return out;
    }
    function cmp(a,b,key){
      if(key==='logK'){
        const na = toNum(a[key]), nb = toNum(b[key]);
        if(na!==null && nb!==null) return na-nb;
      }
      return String(a[key]||'').localeCompare(String(b[key]||''), undefined, {numeric:true, sensitivity:'base'});
    }

    function render(){
      let rows = data.filter(r => {
        if (selectedAtoms.size > 0) {
          const atomSet = extractAtomsFromText((r.product || '') + ' ' + (r.equation_full || ''));
          for (const a of selectedAtoms) { if (!atomSet.has(a)) return false; }
        }
        return true;
      });
      rows.sort((a,b) => sortAsc ? cmp(a,b,sortKey) : -cmp(a,b,sortKey));
      count.textContent = rows.length;
      tbody.innerHTML = rows.map(r => `
        <tr>
          <td class="mono">${r.product||''}</td>
          <td class="mono">${r.equation_full||''}</td>
          <td class="mono">${r.logK||''}</td>
          <td class="mono">${r.contributing_logK||''}</td>
          <td>${r.experimental_conditions||''}</td>
          <td>${r.database_comments||''}</td>
          <td>${r.reference_consolidated||''}</td>
        </tr>`).join('');
    }

    headers.forEach(h => h.addEventListener('click', () => {
      const k = h.getAttribute('data-k');
      if (sortKey === k) sortAsc = !sortAsc; else { sortKey = k; sortAsc = true; }
      render();
    }));
    render();
  </script>
</body>
</html>
'@
$html = $html.Replace('__JSON_DATA__', $jsonData)
[System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.Encoding]::UTF8)

Write-Output ('Created: {0}' -f $tsvPath)
Write-Output ('Created: {0}' -f $mdPath)
Write-Output ('Created: {0}' -f $htmlPath)
Write-Output ('Raw records: {0}; merged records: {1}' -f $rawCount, $mergedCount)
