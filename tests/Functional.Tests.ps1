<#
.SYNOPSIS
    Pester functional tests for Enshrouded server management.
.DESCRIPTION
    Validates that project scripts and config are structurally correct.
    NEVER dot-sources, imports, or executes any project script.
    All checks use Get-Content and string matching only.
.NOTES
    File Name : Functional.Tests.ps1
    Requires  : Pester 5.x
#>

Describe "Common-Functions Definitions" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $cfContent = Get-Content (Join-Path $root "scripts\guest\Common-Functions.ps1") -Raw
    }

    It "Defines Write-ServerLog"        { $cfContent | Should -Match 'function Write-ServerLog'        }
    It "Defines Write-EventLogEntry"    { $cfContent | Should -Match 'function Write-EventLogEntry'    }
    It "Defines Test-ServerProcess"     { $cfContent | Should -Match 'function Test-ServerProcess'     }
    It "Defines Get-ServerConfig"       { $cfContent | Should -Match 'function Get-ServerConfig'       }
    It "Defines Test-AdminPrivileges"   { $cfContent | Should -Match 'function Test-AdminPrivileges'   }
    It "Defines Format-ByteSize"        { $cfContent | Should -Match 'function Format-ByteSize'        }
    It "Defines Get-EnvironmentType"    { $cfContent | Should -Match 'function Get-EnvironmentType'    }
    It "Defines Set-GPUConfiguration"   { $cfContent | Should -Match 'function Set-GPUConfiguration'   }
    It "Defines Show-ScriptMenu"        { $cfContent | Should -Match 'function Show-ScriptMenu'        }
}

Describe "Common-Functions Parameters" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $cfContent = Get-Content (Join-Path $root "scripts\guest\Common-Functions.ps1") -Raw
    }

    It "Write-ServerLog has Message parameter"            { $cfContent | Should -Match '\$Message'   }
    It "Write-ServerLog has Level parameter with ValidateSet" { $cfContent | Should -Match "ValidateSet\('INFO', 'WARN', 'ERROR', 'SUCCESS'\)" }
    It "Get-ServerConfig has ConfigPath parameter"        { $cfContent | Should -Match '\$ConfigPath' }
    It "Format-ByteSize has Bytes parameter"              { $cfContent | Should -Match '\$Bytes'      }
}

Describe "Configuration Template" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $configFile = Join-Path $root "config\EnshroudedServerConfig.json"
        $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
    }

    It "Parses as valid JSON"                   { $cfg | Should -Not -BeNullOrEmpty }
    It "Has Server.GamePort = 15636"            { $cfg.Server.GamePort  | Should -Be 15636 }
    It "Has Server.QueryPort = 15637"           { $cfg.Server.QueryPort | Should -Be 15637 }
    It "Has Paths.ServerInstall"                { $cfg.Paths.ServerInstall | Should -Not -BeNullOrEmpty }
    It "Has Backup.RetentionCount"              { $cfg.Backup.RetentionCount | Should -BeGreaterThan 0 }
}

Describe "Script Structure Checks" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $guestDir = Join-Path $root "scripts\guest"
        $scripts = Get-ChildItem $guestDir -Filter *.ps1 -File |
            Where-Object Name -ne 'Common-Functions.ps1'
    }

    It "All guest scripts reference Common-Functions.ps1" {
        foreach ($f in $scripts) {
            $c = Get-Content $f.FullName -Raw
            $c | Should -Match 'Common-Functions\.ps1' -Because "$($f.Name) should source Common-Functions"
        }
    }

    It "All guest scripts call Get-ServerConfig or reference config" {
        foreach ($f in $scripts) {
            $c = Get-Content $f.FullName -Raw
            ($c -match 'Get-ServerConfig' -or $c -match 'EnshroudedServerConfig') |
                Should -Be $true -Because "$($f.Name) should use configuration"
        }
    }
}
