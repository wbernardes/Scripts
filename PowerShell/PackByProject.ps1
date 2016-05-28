Set-ExecutionPolicy Unrestricted

Param (
	[string]$VersionComments
)

###
### Fixed Variables
###

$PathAssemblies = New-Object System.Collections.Generic.List[System.String]

#msbuild .exe path
$ExeMsbuild   = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe"

#nuget .exe path
$ExeNuget     = "Nuget.exe"

#nuget repository path (to send the package after make it)
$NugetRepositoryPath = "..\Build\Packages"

#csproj path list to be generate a nuget package for each one
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

Function Make-Class-Library {
	Param(
		[string] $PathProject,
		[string] $OutputPath
	)

	Process {
		Report-Info "Building Dll from '$PathProject'"
		
		$ProjectPath = Resolve-BasePath $PathProject
		$ProjectOutput = Resolve-BasePath $OutputPath
		
		If (-not(Test-Path $ProjectOutput)) { 
			New-Item -ItemType Directory -Path $ProjectOutput | Out-Null 
		}

		& $ExeMsbuild $ProjectPath /t:"Clean;Rebuild" /nologo /v:"Quiet" /p:"OutputPath=$ProjectOutput" /p:"OutDir=$ProjectOutput" | Out-Null
		
		$result = (gci -Filter "*.dll" -Recurse $ProjectOutput | %{ $_.FullName })
		Return $result
	}
}


Function Make-Nuget-Pack {
	Param (
		[string] $ProjectPath
	)

	Process {
		Report-Info "Packing .project '$ProjectPath'"

		$NupkgBinFolder = Resolve-BasePath $NugetRepositoryPath

		If (-not(Test-Path($NupkgBinFolder))) { 
			New-Item -ItemType Directory -Path $NupkgBinFolder | Out-Null 
		}

		# execute nuget pack
		#& $ExeNuget Pack $ProjectPath -NoPackageAnalysis -NonInteractive -Build -Symbols -IncludeReferencedProjects -Properties Configuration=Release 
		& $ExeNuget Pack $ProjectPath -NoPackageAnalysis -NonInteractive -Build -IncludeReferencedProjects -Properties Configuration=Release 

		Move-Item "*.nupkg" $NupkgBinFolder -Force | Out-Null
		Report-Info "Package for .project '$ProjectPath' created!"
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

Function Display-Pack-Separator {
	Process {
		Write-Host "--------------------------------------------------"
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
		
		ForEach ($PathProject in $PathProjects) {
			
			#Make-Class-Library $PathProject 'lib'
			
			#Append-Assemblies-To-Lib
			
			Display-Pack-Separator

			$ProjectPath  = Resolve-BasePath $PathProject
			$ProjectPath = $ProjectPath.Replace("Build\..\", "")

			Make-Nuget-Pack $ProjectPath

		}

		Display-Footer
	}
}

Run