# Contributing to Enshrouded Server Management

Thank you for your interest in contributing! This project welcomes contributions from the community.

## 🎯 Project Goals

This is an **educational project** demonstrating PowerShell automation for game server management. Contributions should maintain:

- **Simplicity** - Scripts should be readable by PowerShell beginners
- **PowerShell 5.1 compatibility** - No external dependencies
- **Educational value** - Code serves as learning material
- **Windows native approach** - No WSL, Docker, or Linux tools

## 🤝 How to Contribute

### Reporting Issues

**Before creating an issue:**
- Search existing issues to avoid duplicates
- Test with a fresh Windows 11 Pro installation if possible
- Include your environment details (Windows version, PowerShell version)

**Good issue reports include:**
- Clear description of expected vs actual behavior
- Steps to reproduce the problem
- Error messages or screenshots
- Relevant log file excerpts from `ManagementLogs/`

### Suggesting Enhancements

We welcome suggestions for:
- Additional management scripts (monitoring, performance tuning)
- Improved error handling or validation
- Better logging or diagnostic output
- Documentation improvements
- Cross-platform compatibility (if it maintains simplicity)

**Please open an issue first** to discuss major changes before investing time in implementation.

### Pull Requests

**Good pull requests:**

1. **Address a specific issue or enhancement**
   - Reference the issue number in your PR description
   - Keep scope focused (one feature/fix per PR)

2. **Follow existing code style:**
   - Comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.EXAMPLE`, `.NOTES`)
   - Use `Write-ServerLog` for all logging
   - Use `Get-ServerConfig` for configuration access
   - Include error handling with try/catch blocks
   - Test with `Invoke-Pester` before submitting

3. **Include tests:**
   - Add to existing Pester test files or create new ones
   - Ensure all existing tests still pass
   - Document any test requirements in comments

4. **Update documentation:**
   - Update README.MD if changing user-facing behavior
   - Update docs/Spec.MD if changing architecture
   - Add examples for new features

### Code Style Guidelines

**PowerShell Conventions:**
```powershell
# Use approved verbs (Get-, Set-, New-, Remove-, Test-, etc.)
function Test-MyFeature {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RequiredParameter,
        
        [Parameter(Mandatory=$false)]
        [int]$OptionalParameter = 10
    )
    
    # Dot-source common functions
    . "$PSScriptRoot\Common-Functions.ps1"
    
    try {
        Write-ServerLog "Starting operation..." -Level INFO
        
        # Your logic here
        
        Write-ServerLog "Operation completed successfully." -Level SUCCESS
    } catch {
        Write-ServerLog "Error: $($_.Exception.Message)" -Level ERROR
        throw
    }
}
```

**Naming:**
- Scripts: `##-Verb-Noun.ps1` (e.g., `11-Monitor-Performance.ps1`)
- Functions: `Verb-Noun` with approved PowerShell verbs
- Variables: `$camelCase` for local, `$PascalCase` for parameters

**Comments:**
- Explain **why**, not **what** (code should be self-documenting)
- Add comment-based help to all scripts and functions
- Use inline comments for complex business logic

**Error Handling:**
- Use try/catch for operations that might fail
- Log errors before rethrowing or exiting
- Provide actionable error messages

### Testing

**Run tests before submitting:**
```powershell
# Run all tests
Invoke-Pester -Path .\tests\

# Run specific test suite
Invoke-Pester -Path .\tests\Config.Tests.ps1 -Output Detailed
```

**Test coverage expectations:**
- New scripts should have corresponding tests in `Scripts.Tests.ps1`
- New configuration options should have tests in `Config.Tests.ps1`
- New functions should have tests in `Functional.Tests.ps1`

### Documentation

**README.MD updates needed for:**
- New scripts (add to Script Reference table)
- Changed workflows (update workflow examples)
- New configuration options (add to Configuration section)
- Breaking changes (add to Known Limitations)

**Spec.MD updates needed for:**
- Architecture changes
- New dependencies
- Changed directory structure
- Testing strategy changes

## 🚫 What We Don't Accept

- **External dependencies** requiring installation (keep PowerShell 5.1 only)
- **Platform-specific hacks** that break Windows 11 Pro compatibility
- **Security vulnerabilities** (plaintext password storage beyond config file, etc.)
- **Breaking changes without migration path**
- **Undocumented features** (all code must have comment-based help)
- **Code without tests** (minimum: syntax validation tests)

## 📜 Licensing

By contributing, you agree that your contributions will be licensed under the MIT License, the same license covering this project. See [LICENSE](LICENSE) file for details.

## 🎓 Educational Context

This project originated as a summative lab project demonstrating:
- PowerShell scripting best practices
- Windows Server administration automation
- Infrastructure as Code concepts
- Game server lifecycle management

**Keep this educational focus** when contributing. Code should teach as well as work.

## 🔒 Security

**Do not submit:**
- Actual server credentials or passwords
- Real IP addresses or network configurations
- Steam account credentials
- API keys or tokens

See [SECURITY.MD](SECURITY.MD) for security policy and vulnerability reporting.

## 📞 Questions?

- **General questions:** Open a GitHub Discussion or Issue
- **Security concerns:** See [SECURITY.MD](SECURITY.MD)
- **Major feature proposals:** Open an issue first to discuss approach

## 🙏 Recognition

Contributors will be acknowledged in release notes and the project README. Thank you for helping improve this educational resource!

---

**Remember:** This is a learning project. Code clarity and educational value are as important as functionality. 🎯
