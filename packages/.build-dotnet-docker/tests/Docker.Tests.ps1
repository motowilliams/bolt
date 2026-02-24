#Requires -Version 7.0

Describe ".NET Docker Package - Docker-Specific Tests" -Tag "DotNet-Docker" {
    BeforeAll {
        $script:PackageRoot = Split-Path -Path $PSScriptRoot -Parent
        $script:DockerfilePath = Join-Path -Path $script:PackageRoot -ChildPath "Dockerfile"
        $script:TaskFiles = Get-ChildItem -Path $script:PackageRoot -Filter "Invoke-*.ps1" -File -Force
    }

    Context "Dockerfile" {
        It "Should exist in package root" {
            $script:DockerfilePath | Should -Exist
        }

        It "Should have valid FROM instruction using Microsoft dotnet/sdk image" {
            $content = Get-Content -Path $script:DockerfilePath -Raw
            $content | Should -Match "FROM\s+mcr\.microsoft\.com/dotnet/sdk"
        }

        It "Should set WORKDIR to /project" {
            $content = Get-Content -Path $script:DockerfilePath -Raw
            $content | Should -Match "WORKDIR\s+/project"
        }

        It "Should set ENTRYPOINT to dotnet" {
            $content = Get-Content -Path $script:DockerfilePath -Raw
            $content | Should -Match 'ENTRYPOINT\s+\["dotnet"\]'
        }
    }

    Context "Task Scripts - Docker Execution" {
        It "All task scripts should use docker run" {
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                $content | Should -Match "docker run" -Because "$($taskScript.Name) should use docker run for execution"
            }
        }

        It "All task scripts should check Docker availability" {
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                $content | Should -Match "Get-Command docker" -Because "$($taskScript.Name) should check for docker"
            }
        }

        It "All task scripts should build image from Dockerfile" {
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                $content | Should -Match "Dockerfile" -Because "$($taskScript.Name) should reference Dockerfile"
            }
        }

        It "Task scripts should not directly invoke local dotnet CLI" {
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                $content | Should -Not -Match "Get-Command dotnet" -Because "$($taskScript.Name) should use Docker, not local dotnet"
            }
        }
    }

    Context "Environment Variables" {
        It "Should support BOLT_DOTNET_DOCKER_REBUILD for cache invalidation" {
            $found = $false
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                if ($content -match '\$env:BOLT_DOTNET_DOCKER_REBUILD') {
                    $found = $true
                    break
                }
            }
            $found | Should -BeTrue -Because "Task scripts should check BOLT_DOTNET_DOCKER_REBUILD env var for cache control"
        }

        It "BOLT_DOTNET_DOCKER_REBUILD should add --no-cache to docker build" {
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                if ($content -match '\$env:BOLT_DOTNET_DOCKER_REBUILD') {
                    $content | Should -Match "--no-cache" -Because "The rebuild env var should add --no-cache to docker build"
                }
            }
        }
    }

    Context "Docker Image Name" {
        It "All task scripts should use the same image name bolt-dotnet:latest" {
            $imageNames = @()
            foreach ($taskScript in $script:TaskFiles) {
                $content = Get-Content -Path $taskScript.FullName -Raw
                if ($content -match '"(bolt-dotnet:[^"]+)"') {
                    $imageNames += $Matches[1]
                }
            }
            $uniqueNames = @($imageNames | Select-Object -Unique)
            $uniqueNames.Count | Should -Be 1 -Because "All task scripts should use the same Docker image name"
            $uniqueNames[0] | Should -Be "bolt-dotnet:latest"
        }
    }
}
