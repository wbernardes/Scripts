Set-ExecutionPolicy Unrestricted

Param (
	[string]$VersionComments
)

###
### Fixed Variables
###

#msbuild .exe path
$ExeMsbuild   = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"

#nuget .exe path
$ExeNuget = "Nuget.exe"

#nuget repository path (to send the package after make it)
$NugetRepositoryPath = "..\Build\Packages"

#csproj path list to be encapsulated into the nuget package
$PathProjects   = @(
	"..\Worcom.Framework.AspNet.Mvc\Worcom.Framework.AspNet.Mvc.csproj",
	"..\Worcom.Framework.AspNet.WebForms\Worcom.Framework.AspNet.WebForms.csproj",
	"..\Worcom.Framework.BasicAuthentication\Worcom.Framework.BasicAuthentication.csproj",
	"..\Worcom.Framework.Caching\Worcom.Framework.Caching.csproj",
	"..\Worcom.Framework.Configuration\Worcom.Framework.Configuration.csproj",
	"..\Worcom.Framework.Core\Worcom.Framework.Core.csproj",
	"..\Worcom.Framework.Data\Worcom.Framework.Data.csproj",
	"..\Worcom.Framework.Logger\Worcom.Framework.Logger.csproj",
	"..\Worcom.Framework.DomainNotifications\Worcom.Framework.DomainNotifications.csproj",
	"..\Worcom.Framework.Messaging\Worcom.Framework.Messaging.csproj" 
	"..\Worcom.Framework.Native\Worcom.Framework.Native.csproj",
	"..\Worcom.Framework.Net\Worcom.Framework.Net.csproj",
	"..\Worcom.Framework.Scheduling\Worcom.Framework.Scheduling.csproj", 
	"..\Worcom.Framework.Security\Worcom.Framework.Security.csproj",
	"..\Worcom.Framework.Services\Worcom.Framework.Services.csproj",
	"..\Worcom.Framework.Validation\Worcom.Framework.Validation.csproj"
	);

#nuspec base file.
#this file should be used to help the version number creation. if it doesn't exist, it's create automatically.
$PathSpecFile   = "Build.Spec.nuspec"

#nuget package info
$PackageId   = "Worcom.Framework"
$PackageAuthors = "Worcom - Solução em Sistemas LTDA"
$PackageOwners  = "Worcom - Solução em Sistemas LTDA"
$PackageProjectUrl = "http://www.worcom.com.br"
$PackageIconUrl = "http://www.worcom.com.br/icon.png"
$PackageCopyright = "Copyright 2015 - Worcom Solução em Sistemas LTDA"		
$PackageLanguage = "pt-Br"		
$PackageTags = "nuget worcom framework"			


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
		Return "Build.Spec.nuspec"
	}
}

Function Decide-Version-Number {
	Process {
		Report-Info "Creating package version"
		
		# Date Versioning
		#$Version = @{
		#	Year 	=  	(Get-Date).Year	
		#	Month 	= 	(Get-Date).Month
		#	Day 	=   (Get-Date).Day	
		#	Build 	= 	1
		#}

		# Semantic Versioning 2.0.0
		# http://semver.org/
		$Version = @{
			Major		=  	1
			Minor		= 	0
			Build		=   1
			Revision	= 	0
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

				# changes the build number for semantic versioning
				$Version.Build = ([int]::Parse($VersionFrags[2]) + 1).ToString()	

				# changes de build number for date versioning
				#if($VersionFrags[0] -eq $Version.Year) {
				#	if($VersionFrags[1] -eq $Version.Month){
				#		if($VersionFrags[2] -eq $Version.Day) {
				#			$Version.Build = ([int]::Parse($VersionFrags[3]) + 1).ToString()	
				#		}
				#	}
				#}
			}
			catch {
				Write-Error " >>> There was a problem with the file version format.";
			}
		}
		
		# result by Date Versioning
		#$Result = 
		#	$Version.Year.ToString() 	+ "." + 
		#	$Version.Month.ToString() 	+ "." + 
		#	$Version.Day.ToString() 	+ "." + 
		#	$Version.Build.ToString()	

		# result by Semantic Versioning 2.0.0
		$Result = 
			$Version.Major.ToString() 	+ "." + 
			$Version.Minor.ToString() 	+ "." + 
			$Version.Build.ToString() 	+ "." + 
			$Version.Revision.ToString()
		
		Report-Info "New .nuspec version is '$Result'"
			
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
			$LibReferences += "<file src=""lib\{assembly-name}"" target=""lib\net40\{assembly-name}"" />" -replace "{assembly-name}", [System.IO.Path]::GetFileName($PathAssembly)
			$LibReferences += "`n"
		}

		$XmlString = $Tmpl
		
		$XmlString = $XmlString -replace "{assembly-files}", $LibReferences
		$XmlString = $XmlString -replace "{package-id}", $PackageId
		$XmlString = $XmlString -replace "{package-authors}", $PackageAuthors
		$XmlString = $XmlString -replace "{package-owners}", $PackageOwners
		$XmlString = $XmlString -replace "{package-project-url}", $PackageProjectUrl
		$XmlString = $XmlString -replace "{package-icon-url}", $PackageIconUrl
		$XmlString = $XmlString -replace "{package-description}", $PackageProjectUrl
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

		$PkgName =  $PackageId + ".$VersionNumber.nupkg"
		$NupkgPath = Resolve-BasePath $PkgName
		$NupkgBinFolder = Resolve-BasePath $NugetRepositoryPath
		$PkgDestinationPath = "$NupkgBinFolder\$PkgName"
		If (-not(Test-Path($NupkgBinFolder))) { New-Item -ItemType Directory -Path $NupkgBinFolder | Out-Null }

		$FullExeNuget = $ExeNuget 
		& $FullExeNuget Pack $NuspecPath -NoPackageAnalysis -Build -Symbols -Properties Configuration=Release | Out-Null

		Move-Item "*.nupkg" $NupkgBinFolder -Force | Out-Null

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
		
		# if (-not([string]::IsNullOrEmpty($NugetRepositoryPath))) {
		#     If (Test-Path($NugetRepositoryPath)) {
		#         Copy-Item -Path $NupackPath -Destination $NugetRepositoryPath
		#         Report-Info "Package sent to '$NugetRepositoryPath'"
		#     } else {
		#         Write-Warning "Destination path '$NugetRepositoryPath' not exist. The package could not be copied"
		#     }
		# } else {
		#     Write-Warning "Destination path not informed"
		# }

		Display-Footer
	}
}

Run