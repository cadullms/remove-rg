# Dot-Sourcing our Code under Test (System under Test, SUT)
.$PSScriptRoot\Remove-RgAndAssociatedObjects.Implementation.ps1

Describe "Get-AdGroupNamePattern" {

    It "returns 'AdminIT RG PI BASIC 123' for 'MYORG_RG_InternetOnly_Basic_MY_123'" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_InternetOnly_Basic_MY_123"
        $result | Should -Be "AdminIT RG PI BASIC 123"
    }
    
    It "returns 'AdminIT RG PI BASIC 251' for 'MYORG_RG_InternetOnly_Basic_251'" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_InternetOnly_Basic_251"
        $result | Should -Be "AdminIT RG PI BASIC 251"
    }

    It "returns 'AdminIT RG IN BASIC 241' for 'MYORG_RG_Intranet_BASIC_241'" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_Intranet_BASIC_241"
        $result | Should -Be "AdminIT RG IN BASIC 241"
    }

    It "is case insensitive for environment" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_InTrANET_BASIC_241"
        $result | Should -Match " IN "
    }

    It "detects Intranet environment" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_INTRANET_BASIC_241"
        $result | Should -Match " IN "
    }

    It "detects PublicInternet environment" {
        $result = Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_INTERNETONLY_BASIC_241"
        $result | Should -Match " PI "
    }

    It "throws error on invalid environment" {
        {
            Get-AdGroupNamePattern -resourceGroupName "MYORG_RG_INVALID_BASIC_241"
        } | Should -Throw
    }

}