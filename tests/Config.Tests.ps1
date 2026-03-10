<#
.SYNOPSIS
    Pester tests for configuration file validation.
.DESCRIPTION
    Validates EnshroudedServerConfig.json structure and values.
    Safe on any machine - only reads the config JSON file.
.NOTES
    File Name : Config.Tests.ps1
    Requires  : Pester 5.x
#>

Describe "Configuration File Tests" {

    BeforeAll {
        $root = Split-Path -Parent $PSScriptRoot
        $configFile = Join-Path $root "config\EnshroudedServerConfig.json"
        $raw = Get-Content $configFile -Raw -ErrorAction Stop
        $cfg = $raw | ConvertFrom-Json
    }

    It "Config file exists" {
        Test-Path (Join-Path (Split-Path -Parent $PSScriptRoot) "config\EnshroudedServerConfig.json") | Should -Be $true
    }

    It "Parses as valid JSON" {
        $cfg | Should -Not -BeNullOrEmpty
    }

    It "Has Paths section" { $cfg.Paths | Should -Not -BeNullOrEmpty }
    It "Has VM section"    { $cfg.VM    | Should -Not -BeNullOrEmpty }
    It "Has Server section" { $cfg.Server | Should -Not -BeNullOrEmpty }
    It "Has Backup section" { $cfg.Backup | Should -Not -BeNullOrEmpty }
    It "Has Logging section" { $cfg.Logging | Should -Not -BeNullOrEmpty }

    It "Paths.SteamCMD is an absolute path"       { $cfg.Paths.SteamCMD       | Should -Match '^[A-Za-z]:\\' }
    It "Paths.ServerInstall is an absolute path"   { $cfg.Paths.ServerInstall   | Should -Match '^[A-Za-z]:\\' }
    It "Paths.Backup is an absolute path"          { $cfg.Paths.Backup          | Should -Match '^[A-Za-z]:\\' }
    It "Paths.ManagementLogs is an absolute path"  { $cfg.Paths.ManagementLogs  | Should -Match '^[A-Za-z]:\\' }

    It "Server.Name is not empty"       { $cfg.Server.Name      | Should -Not -BeNullOrEmpty }
    It "SlotCount is 1-16"              { $cfg.Server.SlotCount  | Should -BeGreaterThan 0; $cfg.Server.SlotCount | Should -BeLessOrEqual 16 }
    It "GamePort is valid (1-65535)"    { $cfg.Server.GamePort   | Should -BeGreaterThan 0; $cfg.Server.GamePort  | Should -BeLessOrEqual 65535 }
    It "QueryPort is valid (1-65535)"   { $cfg.Server.QueryPort  | Should -BeGreaterThan 0; $cfg.Server.QueryPort | Should -BeLessOrEqual 65535 }
    It "GamePort and QueryPort differ"  { $cfg.Server.GamePort   | Should -Not -Be $cfg.Server.QueryPort }

    It "RetentionCount is 1-100" { $cfg.Backup.RetentionCount | Should -BeGreaterThan 0; $cfg.Backup.RetentionCount | Should -BeLessOrEqual 100 }

    It "Logging.Enabled is boolean" { $cfg.Logging.Enabled | Should -BeIn @($true, $false) }
    It "Logging.Level is valid"     { $cfg.Logging.Level   | Should -BeIn @('INFO','WARN','ERROR','SUCCESS') }

    It "GamePort defaults to 15636"      { $cfg.Server.GamePort         | Should -Be 15636 }
    It "QueryPort defaults to 15637"     { $cfg.Server.QueryPort        | Should -Be 15637 }
    It "SlotCount defaults to 4"         { $cfg.Server.SlotCount        | Should -Be 4 }
    It "RetentionCount defaults to 5"    { $cfg.Backup.RetentionCount   | Should -Be 5 }
}
