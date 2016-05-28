Param (
    [string]$VersionComments
)

###
### Fixed Variables
###

#msbuild .exe path
$ExeMsbuild   = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"

#nuget .exe path
$ExeNuget     = "Nuget.exe"

#nuget repository path (to send the package after make it)
$NugetRepositoryPath = ".\Build\NugetPackages"

#nuspec base file.
#this file should be used to help the version number creation. if it doesn't exist, it's create automatically.
$PathSpecFile   = ".\MakeNuget.Spec.nuspec"

#csproj path list to be encapsulated into the nuget package
$PathProjects   = @(
	"..\SomeProject\SomeProject\SomeProject.Domain.csproj", 
	"..\SomeProject\SomeProject.Service\SomeProject.Service.csproj");

#nuget package info
$PackageId = "Package.Sample"
$PackageAuthors = "Worcom Solução em Sistemas"
$PackageOwners  = "Worcom Solução em Sistemas"
$PackageProjectUrl = "http://www.worcom.com.br"
$PackageIconUrl = "http://www.worcom.com.br/icon.png"
$PackageCopyright = "Copyright � Worcom Solução em Sistemas 2015"		
$PackageLanguage = "pt-Br"		
$PackageTags = "nuget worcom"		


$PathAssemblies = New-Object System.Collections.Generic.List[System.String]

Function Resolve-BasePath {
    Param (
        [string] $Path
    )

    Process {
        if ($PSScriptRoot -eq $null) {
    		$PSScriptRoot = Split-Path -Parent $MyInvocation.ScriptName
    	}
        $FullPath = Join-Path $PSScriptRoot $Path
        Return $FullPath
    }
}

Function Resolve-NuspecName {
    Param (
        [string] $VersionNumber
    )

    Process {
        Return "Make.Spec.nuspec"
    }
}

Function Decide-Version-Number {
    Process {
        Report-Info "Creating package version"
		
		$Version = @{
			Year 	=  	(Get-Date).Year	
			Month 	= 	(Get-Date).Month
			Day 	=   (Get-Date).Day	
			Build 	= 	"1"
		}
		
		$FullPathSpecFile = Resolve-BasePath $PathSpecFile
		If (-not(Test-Path($FullPathSpecFile))) { 
			Write-Warning ">>> File '$FullPathSpecFile' not found!"
		} else
		{
			try {
				[xml] $Xml = Get-Content $PathSpecFile
				$VersionNumber = $Xml.package.metadata.version
				$VersionFrags = $VersionNumber.Split('.');

				if($VersionFrags[0] -eq $Version.Year) {
					if($VersionFrags[1] -eq $Version.Month){
						if($VersionFrags[2] -eq $Version.Day) {
							$Version.Build = ([int]::Parse($VersionFrags[3]) + 1).ToString()	
						}
					}
				}
			}
			catch {
				Write-Error " >>> There was a problem with the file version format.";
			}
		}
		
		$Result = 
			$Version.Year.ToString() 	+ "." + 
			$Version.Month.ToString() 	+ "." + 
			$Version.Day.ToString() 	+ "." + 
			$Version.Build.ToString()
			
		Return $Result
    }
}

Function Set-Project-Version-Number {
    Param (
        [string] $VersionNumber
    )

    Process {
        Report-Info "Setting version '$VersionNumber' to .nuspec"
    }
}

Function Make-Class-Library {
    Param(
        [string] $PathProject,
		[string] $OutputPath
    )

    Process {
        Report-Info "Building Dll from '$PathProject'"
        
        $ProjectPath = Resolve-BasePath $PathProject
        $ProjectOutput = Resolve-BasePath $OutputPath
        If (-not(Test-Path $ProjectOutput)) { New-Item -ItemType Directory -Path $ProjectOutput | Out-Null }

        & $ExeMsbuild $ProjectPath /t:"Clean;Rebuild" /nologo /v:"Quiet" /p:"OutputPath=$ProjectOutput" /p:"OutDir=$ProjectOutput" | Out-Null
        
		$result = (gci -Filter "*.dll" -Recurse $ProjectOutput | %{ $_.FullName })
        Return $result
    }
}

Function Make-Nuget-Spec {
    Param (
        [string] $VersionNumber
    )

    Process {
	
        Report-Info "Creating package .nuspec"

        $Tmpl = @"
<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://schemas.microsoft.com/packaging/2011/08/nuspec.xsd">
    <metadata>
        <id>{package-id}</id>
        <version>{version-number}</version>
        <authors>{package-authors}</authors>
        <owners>{package-owners}</owners>
        <projectUrl>{package-project-url}</projectUrl>
        <iconUrl>{package-icon-url}</iconUrl>
        <requireLicenseAcceptance>false</requireLicenseAcceptance>
        <description>{package-description}</description>
        <summary />
        <releaseNotes>{release-notes}</releaseNotes>
        <copyright>{project-copyright}</copyright>
        <language>{project-language}</language>
        <tags>{project-tags}</tags>
    </metadata>
	<files>
		{assembly-files}
    </files>
</package>
"@

		$LibReferences = "";
		ForEach ($PathAssembly in $PathAssemblies) {
			$LibReferences += "        <file src=""lib\{assembly-name}"" target=""lib\net40\{assembly-name}"" />" -replace "{assembly-name}", [System.IO.Path]::GetFileName($PathAssembly)
			$LibReferences += "`n"
		}

        $XmlString = $Tmpl
		
		$XmlString = $XmlString -replace "{assembly-files}", $LibReferences
		$XmlString = $XmlString -replace "{package-id}", $PackageId
		$XmlString = $XmlString -replace "{package-authors}", $PackageAuthors
		$XmlString = $XmlString -replace "{package-owners}", $PackageOwners
		$XmlString = $XmlString -replace "{package-project-url}", $PackageProjectUrl
		$XmlString = $XmlString -replace "{package-icon-url}", $PackageIconUrl
		$XmlString = $XmlString -replace "{package-description}", $PackageIconUrl
		$XmlString = $XmlString -replace "{project-copyright}", $PackageCopyright
		$XmlString = $XmlString -replace "{project-language}", $PackageLanguage
		$XmlString = $XmlString -replace "{project-tags}", $PackageTags
		
        $XmlString = $XmlString -replace "{version-number}", $VersionNumber
        $XmlString = $XmlString -replace "{release-notes}", $VersionComments
		
		$NuspecName = Resolve-NuspecName
        $NuspecPath = Resolve-BasePath $NuspecName
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
        [System.IO.File]::WriteAllLines($NuspecPath, $XmlString, $Utf8NoBomEncoding)

        Return $NuspecPath
    }
}

Function Make-Nuget-Pack {
    Param (
        [string] $NuspecPath,
        [string] $VersionNumber
    )

    Process {

        Report-Info "Packing nuspec '$NuspecPath'"

        $PkgName = $PackageId + ".$VersionNumber.nupkg"
        $NupkgPath = Resolve-BasePath $PkgName
        $NupkgBinFolder = Resolve-BasePath "bin"
        $PkgDestinationPath = "$NupkgBinFolder\$PkgName"
        If (-not(Test-Path($NupkgBinFolder))) { 
            New-Item -ItemType Directory -Path $NupkgBinFolder | Out-Null 
        }

        #$FullExeNuget = Resolve-BasePath $ExeNuget
        $FullExeNuget = $ExeNuget
        & $FullExeNuget Pack $NuspecPath -NoPackageAnalysis -Build -Symbols -Properties Configuration=Release | Out-Null

        Move-Item $NupkgPath $NupkgBinFolder -Force | Out-Null

		Report-Info "Package '$PkgName' created!"
		
        Return $PkgDestinationPath
    }
}


Function Display-Logo {
    Process {
        Clear
        Write-Host "=================================================="
        Write-Host "Starting .nuget package build process "
        Write-Host "=================================================="
    }
}

Function Display-Footer {
    Process {
        Write-Host "=================================================="
    }
}

Function Report-Info {
    Param (
        [string] $Message
    )
    Process {
        Write-Host " - $Message"
    }
}

Function Append-Assemblies-To-Lib() {
    ForEach($ResultAssembly in $ResultAssemblies) {
        $ResultFileName = [System.IO.Path]::GetFileName($ResultAssembly)
        $ExistingFileNames = $PathAssemblies | Where-Object { $_ -ne $null -and $_.EndsWith($ResultFileName) }
        If ($ExistingFileNames.Length -eq 0) {
            $PathAssemblies.Add($ResultAssembly)
        }
    }
}

Function Run {
    Process {
        Display-Logo

        $VersionNumber = Decide-Version-Number
        Set-Project-Version-Number $VersionNumber
        
        ForEach ($PathProject in $PathProjects) {
            $ResultAssemblies = Make-Class-Library $PathProject 'lib'
        }
		
		Append-Assemblies-To-Lib
		
        $NuspecPath = Make-Nuget-Spec $VersionNumber
        $NupackPath = Make-Nuget-Pack $NuspecPath $VersionNumber
        
        if (-not([string]::IsNullOrEmpty($NugetRepositoryPath))) {
            If (Test-Path($NugetRepositoryPath)) {
                Copy-Item -Path $NupackPath -Destination $NugetRepositoryPath
				Report-Info "Package sent to '$NugetRepositoryPath'"
            } else {
				Write-Warning "Destination path '$NugetRepositoryPath' not exist. The package could not be copied"
			}
        } else {
			Write-Warning "Destination path not informed"
		}

        Display-Footer
    }
}

Run