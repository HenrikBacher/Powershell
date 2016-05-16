<#
.Synopsis
   Import driver to local driver store
.DESCRIPTION
   Import the sepcified driver to the driver store using pnputil
.EXAMPLE
   Import-Driver -Path C:\Temp\iastorac.inf
#>
function Import-Driver
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        #Full path for driver inf file
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        [string]$Path
    )
    
        if (Test-Path $Path)
        {
            pnputil -i -a $Path
        }
        else
        {
            Write-Error -Message "Invalid Path"
        }
}