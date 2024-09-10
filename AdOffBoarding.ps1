<#
.SYNOPSIS
Automates the process of terminating a user's account in Active Directory and clearing memberof and attributes.
.DESCRIPTION
This script performs the following actions to terminate a user's account in Active Directory:
- Clears the manager attribute of the user.
- Removes the user from all group memberships.
- Moves the user to a specified OU (Marked for Deletion).
- Disables the user account.
.PARAMETER upn
The User Principal Name (UPN) of the account to be disabled.
.PARAMETER targetOU
The target Organizational Unit (OU) where the user account will be moved. Default is "OU=Marked for deletion,DC=example,DC=com".

#>
param (
    [string]$upn,
    [string]$targetOU = "OU=Terminated,DC=example,DC=com"
)

Import-Module ActiveDirectory

# Function to clear the manager attribute
function Clear-Manager {
    param (
        [Parameter(ValueFromPipeline=$true)]
        [string]$upn
    )

    Set-ADUser -Identity "$upn" -Clear Manager
    Write-Output "Cleared the manager for $upn"
}

# Function to disable a user
function Disable-UserAccount {
    param (
        [string]$upn,
        [string]$targetOU
    )

    $user = Get-ADUser -Filter "UserPrincipalName -eq '$upn'" -Property Description, Manager -ErrorAction SilentlyContinue
    if ($null -eq $user) {
        Write-Output "The user with UPN '$upn' does not exist in Active Directory."
        return
    }

    if ($user.Enabled -eq $false) {
        Write-Output "The account with UPN '$upn' is already disabled."
        return
    }

    # displays information to verify the correct user
    Write-Output "User: $upn"
    Write-Output "Object Location: $($user.DistinguishedName)"
    Write-Output "Description: $($user.Description)"
    $confirmation = Read-Host -Prompt "Are you sure you want to disable the account with UPN $upn? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Output "Action cancelled."
        return
    }

    Disable-ADAccount -Identity $user.DistinguishedName

    $groups = Get-ADUser -Identity $user.DistinguishedName -Property MemberOf | Select-Object -ExpandProperty MemberOf
    foreach ($group in $groups) {
        Remove-ADGroupMember -Identity $group -Members $user.DistinguishedName -Confirm:$false
    }

    Move-ADObject -Identity $user.DistinguishedName -TargetPath $targetOU

    $user.DistinguishedName | Clear-Manager

    Write-Output "User with UPN $upn has been disabled, removed from all groups, and moved to Marked for Deletion"
}

# Main loop
do {
    $upn = Read-Host -Prompt 'Enter the UPN of the account to disable'
    Disable-UserAccount -upn $upn -targetOU $targetOU
    $choice = Read-Host -Prompt "Do you want to disable another user? (yes/no)"
} while ($choice -eq "yes")
