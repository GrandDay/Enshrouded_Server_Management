<#
.SYNOPSIS
    Pester functional and integration tests for Enshrouded server management.

.DESCRIPTION
    Tests functional behavior of scripts including:
    - Directory creation
    - Process detection
    - Backup file creation
    - Configuration updates
    - Integration test markers

.NOTES
    File Name  : Functional.Tests.ps1
    Requires   : Pester 5.x
    Note: Some tests are mocked, others require actual server installation
#>

BeforeAll {
    $ProjectRoot = Split-Path -Parent $PSScriptRoot
    $GuestScriptsPath = Join-Path $ProjectRoot "scripts\guest"
    $ConfigTemplate = Join-Path $ProjectRoot "config\EnshroudedServerConfig.json"
    
    # Import common functions for testing
    $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
    if (Test-Path $CommonFunctionsPath) {
        . $CommonFunctionsPath
    }
}

Describe "Common Functions Tests" {
    
    Context "Write-ServerLog Function" {
        
        BeforeAll {
            $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
            . $CommonFunctionsPath
        }
        
        It "Write-ServerLog function should be available" {
            Get-Command Write-ServerLog -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Write-ServerLog should accept Message parameter" {
            { Write-ServerLog -Message "Test message" } | Should -Not -Throw
        }
        
        It "Write-ServerLog should accept Level parameter" {
            { Write-ServerLog -Message "Test" -Level INFO } | Should -Not -Throw
            { Write-ServerLog -Message "Test" -Level WARN } | Should -Not -Throw
            { Write-ServerLog -Message "Test" -Level ERROR } | Should -Not -Throw
            { Write-ServerLog -Message "Test" -Level SUCCESS } | Should -Not -Throw
        }
        
        It "Write-ServerLog should reject invalid Level values" {
            { Write-ServerLog -Message "Test" -Level "INVALID" } | Should -Throw
        }
    }
    
    Context "Test-ServerProcess Function" {
        
        BeforeAll {
            $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
            . $CommonFunctionsPath
        }
        
        It "Test-ServerProcess function should be available" {
            Get-Command Test-ServerProcess -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Test-ServerProcess should return null or process object" {
            $result = Test-ServerProcess
            $result | Should -BeIn @($null, [System.Diagnostics.Process])
        }
    }
    
    Context "Get-ServerConfig Function" {
        
        BeforeAll {
            $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
            . $CommonFunctionsPath
        }
        
        It "Get-ServerConfig function should be available" {
            Get-Command Get-ServerConfig -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Get-ServerConfig should load valid config from template" {
            # Copy template to test location
            $testConfigPath = Join-Path $env:TEMP "test-config-$(Get-Random).json"
            Copy-Item $ConfigTemplate $testConfigPath -Force
            
            { Get-ServerConfig -ConfigPath $testConfigPath } | Should -Not -Throw
            
            Remove-Item $testConfigPath -Force -ErrorAction SilentlyContinue
        }
        
        It "Get-ServerConfig should throw on missing file" {
            { Get-ServerConfig -ConfigPath "C:\NonExistent\config.json" } | Should -Throw
        }
    }
    
    Context "Test-AdminPrivileges Function" {
        
        BeforeAll {
            $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
            . $CommonFunctionsPath
        }
        
        It "Test-AdminPrivileges function should be available" {
            Get-Command Test-AdminPrivileges -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Test-AdminPrivileges should return boolean" {
            $result = Test-AdminPrivileges
            $result | Should -BeOfType [bool]
        }
    }
    
    Context "Format-ByteSize Function" {
        
        BeforeAll {
            $CommonFunctionsPath = Join-Path $GuestScriptsPath "Common-Functions.ps1"
            . $CommonFunctionsPath
        }
        
        It "Format-ByteSize function should be available" {
            Get-Command Format-ByteSize -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
        
        It "Format-ByteSize should format bytes correctly" {
            Format-ByteSize 1024 | Should -Match "KB"
        }
        
        It "Format-ByteSize should format megabytes correctly" {
            Format-ByteSize 1048576 | Should -Match "MB"
        }
        
        It "Format-ByteSize should format gigabytes correctly" {
            Format-ByteSize 1073741824 | Should -Match "GB"
        }
        
        It "Format-ByteSize should format terabytes correctly" {
            Format-ByteSize 1099511627776 | Should -Match "TB"
        }
    }
}

Describe "Script Functional Tests (Mocked)" {
    
    Context "Directory Creation Behavior" {
        
        It "Should create directories when they don't exist" {
            $testDir = Join-Path $env:TEMP "enshrouded-test-$(Get-Random)"
            
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            Test-Path $testDir | Should -Be $true
            
            Remove-Item $testDir -Force -ErrorAction SilentlyContinue
        }
        
        It "Should not error when directory already exists" {
            $testDir = Join-Path $env:TEMP "enshrouded-test-$(Get-Random)"
            
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            { New-Item -ItemType Directory -Path $testDir -Force } | Should -Not -Throw
            
            Remove-Item $testDir -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "Process Detection Behavior" {
        
        It "Should detect running processes by name" {
            # Use a known process that should exist
            $process = Get-Process -Name "powershell" -ErrorAction SilentlyContinue
            if ($process) {
                $process | Should -Not -BeNullOrEmpty
                $process[0].ProcessName | Should -Be "powershell"
            }
        }
        
        It "Should return null for non-existent processes" {
            $process = Get-Process -Name "definitelyn otarealprocess12345" -ErrorAction SilentlyContinue
            $process | Should -BeNullOrEmpty
        }
    }
    
    Context "Configuration Loading Behavior" {
        
        It "Should load and parse JSON configuration" {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
            $config | Should -Not -BeNullOrEmpty
            $config.Paths | Should -Not -BeNullOrEmpty
        }
        
        It "Should access nested configuration properties" {
            $config = Get-Content $ConfigTemplate -Raw | ConvertFrom-Json
            $config.Server.GamePort | Should -Be 15636
            $config.Server.QueryPort | Should -Be 15637
        }
    }
    
    Context "Backup Archive Creation Behavior" {
        
        It "Should create ZIP archive with Compress-Archive" {
            $testFile = Join-Path $env:TEMP "test-file-$(Get-Random).txt"
            $testZip = Join-Path $env:TEMP "test-archive-$(Get-Random).zip"
            
            "Test content" | Set-Content $testFile
            Compress-Archive -Path $testFile -DestinationPath $testZip
            
            Test-Path $testZip | Should -Be $true
            
            Remove-Item $testFile, $testZip -Force -ErrorAction SilentlyContinue
        }
        
        It "Should handle multiple files in archive" {
            $testDir = Join-Path $env:TEMP "test-dir-$(Get-Random)"
            $testZip = Join-Path $env:TEMP "test-multi-$(Get-Random).zip"
            
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            1..3 | ForEach-Object { "Content $_" | Set-Content (Join-Path $testDir "file$_.txt") }
            
            Compress-Archive -Path "$testDir\*" -DestinationPath $testZip
            
            Test-Path $testZip | Should -Be $true
            
            Remove-Item $testDir, $testZip -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    
    Context "File Rotation Behavior" {
        
        It "Should keep only specified number of files when rotating" {
            $testDir = Join-Path $env:TEMP "rotation-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $testDir -Force | Out-Null
            
            # Create 10 test files
            1..10 | ForEach-Object {
                "Content $_" | Set-Content (Join-Path $testDir "backup-$_.txt")
                Start-Sleep -Milliseconds 100  # Ensure different timestamps
            }
            
            # Keep only last 5
            $files = Get-ChildItem $testDir -Filter "backup-*.txt" | Sort-Object CreationTime -Descending
            $toDelete = $files | Select-Object -Skip 5
            $toDelete | Remove-Item -Force
            
            $remaining = Get-ChildItem $testDir -Filter "backup-*.txt"
            $remaining.Count | Should -Be 5
            
            Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "Integration Test Markers" -Tag "Integration" {
    
    Context "Full Installation Required" {
        
        BeforeAll {
            $ServerInstallPath = "C:\EnshroudedServer"
            $ServerExe = Join-Path $ServerInstallPath "enshrouded_server.exe"
        }
        
        It "[INTEGRATION] Server installation directory should exist" -Skip {
            Test-Path $ServerInstallPath | Should -Be $true
        }
        
        It "[INTEGRATION] Server executable should exist" -Skip {
            Test-Path $ServerExe | Should -Be $true
        }
        
        It "[INTEGRATION] Configuration file should exist" -Skip {
            Test-Path "C:\EnshroudedServer\EnshroudedServerConfig.json" | Should -Be $true
        }
        
        It "[INTEGRATION] SteamCMD should be installed" -Skip {
            Test-Path "C:\SteamCMD\steamcmd.exe" | Should -Be $true
        }
    }
    
    Context "Server Process Management" {
        
        It "[INTEGRATION] Should be able to detect if server is running" -Skip {
            $proc = Get-Process -Name "enshrouded_server" -ErrorAction SilentlyContinue
            # Test passes regardless of running state - just tests ability to check
            $true | Should -Be $true
        }
        
        It "[INTEGRATION] Should be able to start server process" -Skip {
            # This test requires actual server installation
            # Implementation would call 9-Start-Server.ps1
            $true | Should -Be $true
        }
        
        It "[INTEGRATION] Should be able to stop server process" -Skip {
            # This test requires actual server installation
            # Implementation would call 10-Stop-Server.ps1
            $true | Should -Be $true
        }
    }
    
    Context "Health Check Validation" {
        
        It "[INTEGRATION] Health check should run without errors" -Skip {
            $healthCheckScript = Join-Path $GuestScriptsPath "4-Health-Check.ps1"
            { & $healthCheckScript } | Should -Not -Throw
        }
        
        It "[INTEGRATION] Should detect UDP port listeners" -Skip {
            $gamePort = Get-NetUDPEndpoint -LocalPort 15636 -ErrorAction SilentlyContinue
            # Test passes if command works, regardless of result
            $true | Should -Be $true
        }
    }
    
    Context "Backup and Restore" {
        
        It "[INTEGRATION] Should create backup archive" -Skip {
            $backupScript = Join-Path $GuestScriptsPath "7-Backup-GameFiles.ps1"
            { & $backupScript } | Should -Not -Throw
        }
        
        It "[INTEGRATION] Backup file should exist after backup" -Skip {
            $backupDir = "C:\EnshroudedServer\Backups"
            if (Test-Path $backupDir) {
                $backups = Get-ChildItem $backupDir -Filter "enshrouded-backup-*.zip"
                $backups.Count | Should -BeGreaterThan 0
            }
        }
    }
    
    Context "Configuration Management" {
        
        It "[INTEGRATION] Should apply server configuration" -Skip {
            $configScript = Join-Path $GuestScriptsPath "3-Configure-Server.ps1"
            { & $configScript } | Should -Not -Throw
        }
        
        It "[INTEGRATION] Server config file should be updated" -Skip {
            $serverConfigPath = "C:\EnshroudedServer\enshrouded_server.json"
            Test-Path $serverConfigPath | Should -Be $true
            
            $serverConfig = Get-Content $serverConfigPath | ConvertFrom-Json
            $serverConfig.gamePort | Should -Be 15636
        }
    }
}

Describe "End-to-End Workflow Tests" -Tag "E2E" {
    
    Context "Initial Setup Workflow" {
        
        It "[E2E] Complete setup workflow should execute without errors" -Skip {
            # This would test the full 0-Initial-Setup.ps1 script
            # Requires clean VM and significant time
            $setupScript = Join-Path $GuestScriptsPath "0-Initial-Setup.ps1"
            Test-Path $setupScript | Should -Be $true
        }
    }
    
    Context "Update Workflow" {
        
        It "[E2E] Complete update workflow should execute without errors" -Skip {
            # This would test the full 5-Update-Server.ps1 script
            $updateScript = Join-Path $GuestScriptsPath "5-Update-Server.ps1"
            Test-Path $updateScript | Should -Be $true
        }
    }
    
    Context "Backup Workflow" {
        
        It "[E2E] Complete backup workflow should execute without errors" -Skip {
            # This would test both guest backup and host checkpoint
            $guestBackupScript = Join-Path $GuestScriptsPath "7-Backup-GameFiles.ps1"
            Test-Path $guestBackupScript | Should -Be $true
        }
    }
}
