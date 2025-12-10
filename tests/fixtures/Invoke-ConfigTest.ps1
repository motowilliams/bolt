# TASK: config-test
# DESCRIPTION: Test config injection
# DEPENDS:

Write-Host "Testing config injection..." -ForegroundColor Cyan

# Verify $BoltConfig exists
if (-not $BoltConfig) {
    Write-Host "✗ BoltConfig not injected!" -ForegroundColor Red
    exit 1
}

# Display config properties
Write-Host "✓ BoltConfig injected successfully" -ForegroundColor Green
Write-Host "  ProjectRoot: $($BoltConfig.ProjectRoot)" -ForegroundColor Gray
Write-Host "  TaskDirectory: $($BoltConfig.TaskDirectory)" -ForegroundColor Gray
Write-Host "  TaskName: $($BoltConfig.TaskName)" -ForegroundColor Gray

# Test user-defined variables
if ($BoltConfig.IacPath) {
    Write-Host "  IacPath (user): $($BoltConfig.IacPath)" -ForegroundColor Gray
}

if ($BoltConfig.TestVariable) {
    Write-Host "  TestVariable (user): $($BoltConfig.TestVariable)" -ForegroundColor Gray
}

# Test built-in colors
if ($BoltConfig.Colors) {
    Write-Host "  Colors.Success: $($BoltConfig.Colors.Success)" -ForegroundColor Gray
}

exit 0
