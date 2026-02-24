<#
.SYNOPSIS
    Pester tests for configuration file validation.

.DESCRIPTION
    Tests the EnshroudedServerConfig.json configuration file for:
    - Valid JSON syntax
    - Required keys present
    - Path formats valid
    - Port numbers in range
    - Retention count valid

.NOTES
    File Name  : Config.Tests.ps1
    Requires   : Pester 5.x
#>

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $ConfigTemplate = Join-Path $ProjectRoot "config\EnshroudedServerConfig.json"
}

Describe "Configuration File Tests" {
    
    Context "Configuration Template Exists" {
        
        It "Configuration template file should exist" {
            $ConfigTemplate | Should -Exist
        }
    }
    
    Context "JSON Syntax Validation" {
        
        It "Configuration template should be valid JSON" {
            { Get-Content $ConfigTemplate -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
        
        It "Configuration template should parse to a PowerShell object" {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Required Keys Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have 'Paths' section" {
            $config.Paths | Should -Not -BeNullOrEmpty
        }
        
        It "Should have 'VM' section" {
            $config.VM | Should -Not -BeNullOrEmpty
        }
        
        It "Should have 'Server' section" {
            $config.Server | Should -Not -BeNullOrEmpty
        }
        
        It "Should have 'Backup' section" {
            $config.Backup | Should -Not -BeNullOrEmpty
        }
        
        It "Should have 'Logging' section" {
            $config.Logging | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Paths Section Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have SteamCMD path" {
            $config.Paths.SteamCMD | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ServerInstall path" {
            $config.Paths.ServerInstall | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Backup path" {
            $config.Paths.Backup | Should -Not -BeNullOrEmpty
        }
        
        It "Should have ManagementLogs path" {
            $config.Paths.ManagementLogs | Should -Not -BeNullOrEmpty
        }
        
        It "All paths should be absolute Windows paths" {
            $config.Paths.PSObject.Properties | ForEach-Object {
                $_.Value | Should -Match '^[A-Za-z]:\\'
            }
        }
    }
    
    Context "VM Section Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have VM Name" {
            $config.VM.Name | Should -Not -BeNullOrEmpty
        }
        
        It "VM Name should be a valid string" {
            $config.VM.Name | Should -BeOfType [string]
        }
        
        It "Should have HostPowerShellRemotingEnabled setting" {
            $config.VM.PSObject.Properties.Name | Should -Contain "HostPowerShellRemotingEnabled"
        }
        
        It "HostPowerShellRemotingEnabled should be a boolean" {
            $config.VM.HostPowerShellRemotingEnabled | Should -BeIn @($true, $false)
        }
    }
    
    Context "Server Section Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have Server Name" {
            $config.Server.PSObject.Properties.Name | Should -Contain "Name"
        }
        
        It "Should have Password field (can be empty)" {
            $config.Server.PSObject.Properties.Name | Should -Contain "Password"
        }
        
        It "Should have SlotCount" {
            $config.Server.SlotCount | Should -Not -BeNullOrEmpty
        }
        
        It "SlotCount should be a positive integer" {
            $config.Server.SlotCount | Should -BeOfType [int]
            $config.Server.SlotCount | Should -BeGreaterThan 0
        }
        
        It "SlotCount should be reasonable (1-16)" {
            $config.Server.SlotCount | Should -BeIn 1..16
        }
        
        It "Should have GamePort" {
            $config.Server.GamePort | Should -Not -BeNullOrEmpty
        }
        
        It "GamePort should be in valid range (1-65535)" {
            $config.Server.GamePort | Should -BeGreaterThan 0
            $config.Server.GamePort | Should -BeLessOrEqual 65535
        }
        
        It "Should have QueryPort" {
            $config.Server.QueryPort | Should -Not -BeNullOrEmpty
        }
        
        It "QueryPort should be in valid range (1-65535)" {
            $config.Server.QueryPort | Should -BeGreaterThan 0
            $config.Server.QueryPort | Should -BeLessOrEqual 65535
        }
        
        It "GamePort and QueryPort should be different" {
            $config.Server.GamePort | Should -Not -Be $config.Server.QueryPort
        }
    }
    
    Context "Backup Section Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have RetentionCount" {
            $config.Backup.RetentionCount | Should -Not -BeNullOrEmpty
        }
        
        It "RetentionCount should be a positive integer" {
            $config.Backup.RetentionCount | Should -BeOfType [int]
            $config.Backup.RetentionCount | Should -BeGreaterThan 0
        }
        
        It "RetentionCount should be reasonable (1-100)" {
            $config.Backup.RetentionCount | Should -BeIn 1..100
        }
    }
    
    Context "Logging Section Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "Should have Enabled flag" {
            $config.Logging.PSObject.Properties.Name | Should -Contain "Enabled"
        }
        
        It "Enabled should be a boolean" {
            $config.Logging.Enabled | Should -BeIn @($true, $false)
        }
        
        It "Should have Level setting" {
            $config.Logging.Level | Should -Not -BeNullOrEmpty
        }
        
        It "Level should be a valid log level" {
            $config.Logging.Level | Should -BeIn @('INFO', 'WARN', 'ERROR', 'SUCCESS')
        }
    }
    
    Context "Default Values Validation" {
        
        BeforeAll {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
        }
        
        It "GamePort should default to 15636" {
            $config.Server.GamePort | Should -Be 15636
        }
        
        It "QueryPort should default to 15637" {
            $config.Server.QueryPort | Should -Be 15637
        }
        
        It "SlotCount should default to 4" {
            $config.Server.SlotCount | Should -Be 4
        }
        
        It "RetentionCount should default to 5" {
            $config.Backup.RetentionCount | Should -Be 5
        }
        
        It "Logging should be enabled by default" {
            $config.Logging.Enabled | Should -Be $true
        }
    }
}
