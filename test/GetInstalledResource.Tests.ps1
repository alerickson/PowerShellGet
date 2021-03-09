# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

Import-Module "$psscriptroot\PSGetTestUtils.psm1" -Force

Describe 'Test Get-InstalledPSResource for Module' {

    BeforeAll{
        $TestGalleryName = Get-PoshTestGalleryName
        $PSGalleryName = Get-PSGalleryName
        Get-NewPSResourceRepositoryFile
    }

    AfterAll {
        Get-RevertPSResourceRepositoryFile
    }

    # Purpose: Get all resources when no parameters are specified
    # Action: Get-InstalledPSResource
    # Expected-Result: Should get all (more than 1) resources in PSGallery
    It "Get resources without any parameter values" {
        $pkgs = Get-InstalledPSResource
        $pkgs.Count | Should -BeGreaterThan 1
    }

    # Purpose: Get a specific resource by name
    # Action: Get-InstalledPSResource -Name "ContosoServer"
    # Expected Result: Should get ContosoServer resource
    It "Get specific module resource by name" {
        $pkg = Get-InstalledPSReosurce -Name ContosoServer
        $pkg.Name | Should -Be "ContosoServer"
    }

    # Purpose: Get a resource(s) with regex in name parameter
    # Action: Get-InstalledPSResource -Name Contoso*
    # Expected Result: Should get multiple resources,namely atleast ContosoServer, ContosoClient, Contoso
    It "Get multiple resources with wildcard for name param" {
        $pkgs = Get-InstalledPSResource -Name Contoso*
        $pkgs.Count | Should -BeGreaterOrEqual 1
    }

    # Purpose: Get a specific resource with two wildcards in name
    # Action: Get-InstalledPSResource *ontosoServe*
    # Expected Result: Should get the ContosoServer resource
    It "Get specific resource with wildcards for name param" {
        $pkgs = Get-InstalledPSResource *ontosoServe*
        $pkgs.Name | Should -Contain "ContosoServer"
    }

    # Purpose: Get resource when given Name, Version param not null
    # Action: Get-InstalledPSResource -Name ContosoServer -Version
    # Expected Result: Returns ContosoServer resource
    It "find resource when given Name to <Reason> <Version>" -TestCases @(
        @{Version="[2.0.0.0]";          ExpectedVersion="2.0.0.0"; Reason="validate version, exact match"},
        @{Version="2.0.0.0";            ExpectedVersion="2.0.0.0"; Reason="validate version, exact match without bracket syntax"},
        @{Version="[1.0.0.0, 2.5.0.0]"; ExpectedVersion="2.5.0.0"; Reason="validate version, exact range inclusive"},
        @{Version="(1.0.0.0, 2.5.0.0)"; ExpectedVersion="2.0.0.0"; Reason="validate version, exact range exclusive"},
        @{Version="(1.0.0.0,)";         ExpectedVersion="2.5.0.0"; Reason="validate version, minimum version exclusive"},
        @{Version="[1.0.0.0,)";         ExpectedVersion="2.5.0.0"; Reason="validate version, minimum version inclusive"},
        @{Version="(,1.5.0.0)";         ExpectedVersion="1.0.0.0"; Reason="validate version, maximum version exclusive"},
        @{Version="(,1.5.0.0]";         ExpectedVersion="1.5.0.0"; Reason="validate version, maximum version inclusive"},
        @{Version="[1.0.0.0, 2.5.0.0)"; ExpectedVersion="2.0.0.0"; Reason="validate version, mixed inclusive minimum and exclusive maximum version"}    
    ) {
        param($Version, $ExpectedVersion)
        $pkgs = Get-InstalledPSResource -Name "ContosoServer" -Version $Version
        $pkgs.Name | Should -Be "ContosoServer"
        $pkgs.Version | Should -Be $ExpectedVersion
    }

    # Purpose: not find resources with invalid version
    #
    # Action: Find-PSResource -Name "ContosoServer" -Version "(1.5.0.0)"
    #
    # Expected Result: should not return a resource
    It "not find resource with incorrectly formatted version such as <Description>" -TestCases @(
        @{Version='(1.5.0.0)';       Description="exlcusive version (8.1.0.0)"},
        @{Version='[1-5-0-0]';       Description="version formatted with invalid delimiter"},
        @{Version='[1.*.0]';         Description="version with wilcard in middle"},
        @{Version='[*.5.0.0]';       Description="version with wilcard at start"},
        @{Version='[1.*.0.0]';       Description="version with wildcard at second digit"},
        @{Version='[1.5.*.0]';       Description="version with wildcard at third digit"}
        @{Version='[1.5.0.*';        Description="version with wildcard at end"},
        @{Version='[1..0.0]';        Description="version with missing digit in middle"},
        @{Version='[1.5.0.]';        Description="version with missing digit at end"},
        @{Version='[1.5.0.0.0]';     Description="version with more than 4 digits"}
    ) {
        param($Version, $Description)

        $res = $null
        try {
            $res = Find-PSResource -Name "ContosoServer" -Version $Version -Repository $TestGalleryName -ErrorAction Ignore
        }
        catch {}
        
        $res | Should -BeNullOrEmpty
    }

    # Purpose: Get installed resources when given Name, and Version is '*'
    # Action: Get-InstalledPSResource -Name ContosoServer -Version "*"
    # Expected Result: returns 4 ContosoServer resources (of all versions in descending order)
    It "Get resources when given Name,  and Version is '*'" {
        $pkgs = Get-InstalledPSResource -Name ContosoServer -Version "*"
        $pkgs.Count | Should -BeGreaterOrEqual 4
    }

  






    # Purpose: find resource with latest version (including prerelease version) given Prerelease parameter
    #
    # Action: Find-PSResource -Name "test_module" -Prerelease
    #
    # Expected Result: should return latest version (may be a prerelease version)
    It "find resource with latest (including prerelease) version given Prerelease parameter" {
        # test_module resource's latest version is a prerelease version, before that it has a non-prerelease version
        $res = Find-PSResource -Name "test_module"
        $res.Version | Should -Be "5.0.0.0"

        $resPrerelease = Find-PSResource -Name "test_module" -Prerelease
        $resPrerelease.Version | Should -Be "5.2.5.0"        
    }



}
