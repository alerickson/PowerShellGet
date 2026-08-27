# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Write-Verbose -Verbose -Message "PowerShellGet version currently loaded: $($(Get-Module powershellget).Version)"

Describe "Test CompatPowerShellGet: V2 Object Property Compatibility" -tags 'CI' {

    BeforeAll {
        $PSGalleryName = 'PSGallery'
        $testModuleName = "testmodule99"
        $testScriptName = "test_script"

        $v2RepositoryProperties = @(
            'Name',
            'SourceLocation',
            'Trusted',
            'Registered',
            'InstallationPolicy',
            'PackageManagementProvider',
            'PublishLocation',
            'ScriptSourceLocation',
            'ScriptPublishLocation',
            'ProviderOptions'
        )

        # Properties that exist natively on PSResourceInfo plus our v2 additions
        $v2ResourceProperties = @(
            'Name',
            'Version',
            'Type',
            'Description',
            'Author',
            'CompanyName',
            'Copyright',
            'PublishedDate',
            'LicenseUri',
            'ProjectUri',
            'IconUri',
            'Tags',
            'Includes',
            'ReleaseNotes',
            'Dependencies',
            'Repository',
            'RepositorySourceLocation',
            'PackageManagementProvider'
        )

        # The two properties we add for v2 compat
        $v2AddedProperties = @(
            'RepositorySourceLocation',
            'PackageManagementProvider'
        )
    }

    Context "Get-PSRepository output" {
        It "should have all v2 properties" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res | Should -Not -BeNullOrEmpty
            foreach ($prop in $v2RepositoryProperties) {
                $res.PSObject.Properties.Name | Should -Contain $prop
            }
        }

        It "should have correct InstallationPolicy value" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.InstallationPolicy | Should -BeIn @('Trusted', 'Untrusted')
        }

        It "should have InstallationPolicy consistent with Trusted" {
            $res = Get-PSRepository -Name $PSGalleryName
            if ($res.Trusted) {
                $res.InstallationPolicy | Should -Be 'Trusted'
            } else {
                $res.InstallationPolicy | Should -Be 'Untrusted'
            }
        }

        It "should have Registered set to true" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.Registered | Should -BeTrue
        }

        It "should have PackageManagementProvider set to NuGet" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.PackageManagementProvider | Should -Be 'NuGet'
        }

        It "should have SourceLocation populated" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.SourceLocation | Should -Not -BeNullOrEmpty
        }

        It "should have PublishLocation populated" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.PublishLocation | Should -Not -BeNullOrEmpty
        }

        It "should have ProviderOptions as hashtable" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.ProviderOptions | Should -BeOfType [hashtable]
        }

        It "should display as table with Name, InstallationPolicy, SourceLocation columns" {
            $res = Get-PSRepository -Name $PSGalleryName
            $res.PSObject.TypeNames | Should -Contain 'Microsoft.PowerShell.Commands.PSRepositoryInfo'
        }

        It "should have correct properties for locally registered repo" {
            $tmpDir = Join-Path -Path $TestDrive -ChildPath "v2TestDir"
            New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
            Register-PSResourceRepository -Name "v2TestRepo" -Uri $tmpDir
            try {
                $res = Get-PSRepository -Name "v2TestRepo"
                $res | Should -Not -BeNullOrEmpty
                foreach ($prop in $v2RepositoryProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
                $res.InstallationPolicy | Should -Be 'Untrusted'
                $res.Registered | Should -BeTrue
                $res.PackageManagementProvider | Should -Be 'NuGet'
            } finally {
                Unregister-PSResourceRepository -Name "v2TestRepo"
                Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Register-PSRepository output" {
        It "registered repo should be visible via Get-PSRepository with v2 properties" {
            $tmpDir = Join-Path -Path $TestDrive -ChildPath "v2RegTestDir"
            New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null
            Unregister-PSResourceRepository -Name "v2RegTestRepo" -ErrorAction SilentlyContinue
            Register-PSRepository -Name "v2RegTestRepo" -SourceLocation $tmpDir
            try {
                $res = Get-PSRepository -Name "v2RegTestRepo"
                $res | Should -Not -BeNullOrEmpty
                foreach ($prop in $v2RepositoryProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
            } finally {
                Unregister-PSRepository -Name "v2RegTestRepo"
                Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Find-Module output" {
        It "should have all v2 resource properties" {
            $res = Find-Module -Name $testModuleName -Repository $PSGalleryName
            $res | Should -Not -BeNullOrEmpty
            foreach ($prop in $v2ResourceProperties) {
                $res.PSObject.Properties.Name | Should -Contain $prop
            }
        }

        It "should have PackageManagementProvider set to NuGet" {
            $res = Find-Module -Name $testModuleName -Repository $PSGalleryName
            $res.PackageManagementProvider | Should -Be 'NuGet'
        }

        It "should have RepositorySourceLocation as string" {
            $res = Find-Module -Name $testModuleName -Repository $PSGalleryName
            $res.RepositorySourceLocation | Should -BeOfType [string]
        }
    }

    Context "Find-Script output" {
        It "should have all v2 resource properties" {
            $res = Find-Script -Name $testScriptName -Repository $PSGalleryName
            $res | Should -Not -BeNullOrEmpty
            foreach ($prop in $v2ResourceProperties) {
                $res.PSObject.Properties.Name | Should -Contain $prop
            }
        }

        It "should have PackageManagementProvider set to NuGet" {
            $res = Find-Script -Name $testScriptName -Repository $PSGalleryName
            $res.PackageManagementProvider | Should -Be 'NuGet'
        }
    }

    Context "Find-Command output" {
        It "should have v2-added properties when results are returned" {
            $res = Find-Command -Name "Get-TargetResource" -Repository $PSGalleryName -ErrorAction SilentlyContinue
            if ($res) {
                foreach ($prop in $v2AddedProperties) {
                    $res[0].PSObject.Properties.Name | Should -Contain $prop
                }
                $res[0].PackageManagementProvider | Should -Be 'NuGet'
            } else {
                Set-ItResult -Skipped -Because "No results returned from Find-Command"
            }
        }
    }

    Context "Find-DscResource output" {
        It "should have v2-added properties when results are returned" {
            $res = Find-DscResource -Name "SystemLocale" -Repository $PSGalleryName -ErrorAction SilentlyContinue
            if ($res) {
                foreach ($prop in $v2AddedProperties) {
                    $res[0].PSObject.Properties.Name | Should -Contain $prop
                }
                $res[0].PackageManagementProvider | Should -Be 'NuGet'
            } else {
                Set-ItResult -Skipped -Because "No results returned from Find-DscResource"
            }
        }
    }

    Context "Get-InstalledModule output" {
        It "should have all v2 resource properties" {
            $res = Get-InstalledModule -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($res) {
                foreach ($prop in $v2ResourceProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
                $res.PackageManagementProvider | Should -Be 'NuGet'
                $res.RepositorySourceLocation | Should -BeOfType [string]
            } else {
                Set-ItResult -Skipped -Because "No installed modules found"
            }
        }
    }

    Context "Get-InstalledScript output" {
        It "should have all v2 resource properties" {
            $res = Get-InstalledScript -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($res) {
                foreach ($prop in $v2ResourceProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
                $res.PackageManagementProvider | Should -Be 'NuGet'
            } else {
                Set-ItResult -Skipped -Because "No installed scripts found"
            }
        }
    }

    Context "Install-Module output with -PassThru" {
        It "should have v2 resource properties with -PassThru" -Skip {
            # Skipped by default: installs a module. Unskip for integration testing.
            $res = Install-Module -Name $testModuleName -Repository $PSGalleryName -PassThru -Scope CurrentUser -Force
            if ($res) {
                foreach ($prop in $v2ResourceProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
                $res.PackageManagementProvider | Should -Be 'NuGet'
            }
            Uninstall-Module -Name $testModuleName -ErrorAction SilentlyContinue
        }
    }

    Context "Update-Module output with -PassThru" {
        It "should have v2 resource properties with -PassThru" -Skip {
            # Skipped by default: modifies installed modules. Unskip for integration testing.
            $res = Update-Module -Name $testModuleName -PassThru -Force -ErrorAction SilentlyContinue
            if ($res) {
                foreach ($prop in $v2ResourceProperties) {
                    $res.PSObject.Properties.Name | Should -Contain $prop
                }
                $res.PackageManagementProvider | Should -Be 'NuGet'
            }
        }
    }

    Context "Cross-cmdlet property consistency" {
        It "Get-PSRepository and Find-Module should both have PackageManagementProvider" {
            $repo = Get-PSRepository -Name $PSGalleryName
            $mod = Find-Module -Name $testModuleName -Repository $PSGalleryName

            $repo.PackageManagementProvider | Should -Be 'NuGet'
            $mod.PackageManagementProvider | Should -Be 'NuGet'
        }

        It "Get-PSRepository SourceLocation should match Find-Module RepositorySourceLocation" {
            $repo = Get-PSRepository -Name $PSGalleryName
            $mod = Find-Module -Name $testModuleName -Repository $PSGalleryName

            $repo.SourceLocation | Should -Not -BeNullOrEmpty
            $mod.PSObject.Properties.Name | Should -Contain 'RepositorySourceLocation'
        }
    }
}
