# PowerShell version compatibility

AzureLocalRanger supports **PowerShell 7.0 or later (Core edition) only**. Windows PowerShell 5.1 is not supported.

| Edition | Supported | Why |
| --- | --- | --- |
| PowerShell 7.x (7.4 LTS or later recommended) on Windows | Yes | The tested configuration. The code relies on PowerShell 7 language features (`??`, `?.`, ternary, `ConvertFrom-Json -AsHashtable`, pipeline chain operators) and .NET 6+ APIs |
| PowerShell 7.x on Linux or macOS | Reports and comparisons only | Rendering and `Compare-RangerDesign` work from a saved manifest; live discovery needs WinRM to the nodes, which is supported from Windows |
| Windows PowerShell 5.1 | No | Not installed by default alongside the required language features; the module will not import |

The module manifest declares this, and `Test-ModuleManifest` is part of CI (`scripts/ci/Invoke-RangerCi.ps1 -Check Manifest`):

```powershell
$m = Test-ModuleManifest .\AzureLocalRanger.psd1
$m.PowerShellVersion       # 7.0
$m.CompatiblePSEditions    # Core
```

The Azure Local nodes themselves run PowerShell 7.6 (12.2609 (latest)); Ranger runs on the operator's workstation or a jump host, not on the nodes.
