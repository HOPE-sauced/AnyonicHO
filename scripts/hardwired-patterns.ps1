# AnyonicHO Hardwired Patterns
# Synthesized from SpiralSafe, QDI, and HOPE-AI-NPC-SUITE
# Provides callable tools for Agents (Gemini, Claude) and User

$AtomTrailPath = "$env:USERPROFILE\.atom-trail\local-trail.jsonl"
$AtomGlobalContext = "$env:USERPROFILE\.atom-trail\context.json"

function Log-Atom {
    param(
        [Parameter(Mandatory=$true)][string]$Decision,
        [Parameter(Mandatory=$true)][string]$Rationale,
        [string]$Outcome = "pending",
        [int]$CoherenceScore = 0,
        [string[]]$Tags = @()
    )

    $entry = @{
        id = [Guid]::NewGuid().ToString()
        timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        decision = $Decision
        rationale = $Rationale
        outcome = $Outcome
        coherence_score = $CoherenceScore
        tags = $Tags
        agent = "Gemini-CLI"
    }

    $json = $entry | ConvertTo-Json -Compress
    $parent = Split-Path $AtomTrailPath -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    
    Add-Content -Path $AtomTrailPath -Value $json
    Write-Host "ATOM: Logged decision '$Decision'" -ForegroundColor Cyan
}

function Get-AtomTrail {
    param([int]$Last = 10)
    if (Test-Path $AtomTrailPath) {
        Get-Content $AtomTrailPath | Select-Object -Last $Last | ForEach-Object { $_ | ConvertFrom-Json }
    } else {
        Write-Warning "No ATOM trail found at $AtomTrailPath"
    }
}

function Measure-Coherence {
    param(
        [Parameter(Mandatory=$true)][string]$Text,
        [int]$Threshold = 60
    )

    $words = $Text.Split(" ", [StringSplitOptions]::RemoveEmptyEntries)
    $wordCount = $words.Count
    if ($wordCount -eq 0) { 
        return [PSCustomObject]@{ Score = 0; Status = "FAIL" }
    }

    $uniqueWords = ($words | Select-Object -Unique).Count
    $sentences = $Text.Split(".!?", [StringSplitOptions]::RemoveEmptyEntries).Count
    
    $diversity = $uniqueWords / $wordCount
    $avgSentenceLength = if ($sentences -gt 0) { $wordCount / $sentences } else { 0 }
    $structure = if ($Text -match "`n") { 1.0 } else { 0.5 }

    $rawScore = ($diversity * 50) + ([Math]::Min($avgSentenceLength / 20, 1.0) * 30) + ($structure * 20)
    $score = [Math]::Round([Math]::Min($rawScore, 100))

    $status = if ($score -ge $Threshold) { "PASS" } else { "FAIL" }
    $color = if ($status -eq "PASS") { "Green" } else { "Red" }

    Write-Host "WAVE: Coherence Score: $score ($status)" -ForegroundColor $color
    
    return [PSCustomObject]@{
        Score = $score
        Status = $status
        Threshold = $Threshold
        Metrics = @{
            Diversity = $diversity
            AvgSentenceLength = $avgSentenceLength
            Structure = $structure
        }
    }
}

function Resolve-Dispute {
    param(
        [Parameter(Mandatory=$true)][string]$Issue,
        [Parameter(Mandatory=$true)][string]$Resolution,
        [string]$Author = "User"
    )

    Write-Host "SUPERPOSITION LOCK INITIATED" -ForegroundColor Magenta
    
    $coherence = Measure-Coherence -Text "$Issue `n $Resolution"
    
    Log-Atom -Decision "RESOLVE: $Issue" -Rationale $Resolution -Outcome "crystallized" -CoherenceScore $coherence.Score -Tags @("dispute-resolution", "superposition-lock")

    $lockId = "LOCK-" + (Get-Date).ToString("yyyyMMdd-HHmmss")
    $lockContent = @{
        id = $lockId
        issue = $Issue
        resolution = $Resolution
        author = $Author
        timestamp = (Get-Date)
        status = "CRYSTALLIZED"
    } 
    
    $lockPath = "$env:USERPROFILE\.atom-trail\locks\$lockId.json"
    $lockParent = Split-Path $lockPath -Parent
    if (-not (Test-Path $lockParent)) { New-Item -ItemType Directory -Path $lockParent -Force | Out-Null }
    
    $lockContent | ConvertTo-Json | Set-Content -Path $lockPath

    Write-Host "  Issue Crystallized: $lockId" -ForegroundColor Green
    Write-Host "  The spiral continues." -ForegroundColor Gray
}

function Get-CascadingFixes {
    param([string]$Path = ".")
    
    Write-Host "Scouring for cascades in $Path..." -ForegroundColor Cyan
    $patterns = @("TODO", "FIXME", "HACK", "OPTIMIZE")
    
    $results = Get-ChildItem -Path $Path -Recurse -Include *.md,*.ts,*.js,*.ps1,*.py -ErrorAction SilentlyContinue | 
        Select-String -Pattern $patterns -CaseSensitive:$false | 
        Select-Object Path, LineNumber, Line, Pattern
    
    if ($results) {
        $grouped = $results | Group-Object Pattern
        foreach ($g in $grouped) {
            Write-Host "  $($g.Name): $($g.Count) items" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No cascades found." -ForegroundColor Green
    }
    
    return $results
}
