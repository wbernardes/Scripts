param(
    [string]$packageVersion = "1.0.0", #$null,
    [string]$config = "Release",
    #[string[]]$targetFrameworks = @("v4.0", "v4.5", "v4.5.1"),
    [string[]]$targetFrameworks = @("v4.5.2"),
    [string[]]$platforms = @("AnyCpu"),
    [ValidateSet("rebuild", "build")]
    [string]$target = "rebuild",
    [ValidateSet("quiet", "minimal", "normal", "detailed", "diagnostic")]
    [string]$verbosity = "detailed",
    [bool]$alwaysClean = $true
)

# Diagnostic 
function Write-Diagnostic {
    param([string]$message)

    Write-Host
    Write-Host $message -ForegroundColor Green
    Write-Host
}

function Die([string]$message, [object[]]$output) {
    if ($output) {
        Write-Output $output
        $message += ". See output above."
    }
    Write-Error $message
    exit 1
}

function Create-Folder-Safe {
    param(
        [string]$folder = $(throw "-folder is required.")
    )

    if(-not (Test-Path $folder)) {
        [System.IO.Directory]::CreateDirectory($folder)
    }

}

# Build
function Build-Clean {
    param(
        [string]$rootFolder = $(throw "-rootFolder is required."),
        [string]$folders = "bin,obj"
    )

    Write-Diagnostic "Build: Clean"

    Get-ChildItem $rootFolder -Include $folders -Recurse | ForEach-Object {
       Remove-Item $_.fullname -Force -Recurse 
    }
}

function Build-Bootstrap {
    param(
        [string]$solutionFile = $(throw "-solutionFile is required."),
        [string]$nugetExe = $(throw "-nugetExe is required.")
    )

    Write-Diagnostic "Build: Bootstrap"
 
    $solutionFolder = [System.IO.Path]::GetDirectoryName($solutionFile)

    . $nugetExe config -Set Verbosity=quiet
    . $nugetExe restore $solutionFile -NonInteractive

    Get-ChildItem $solutionFolder -filter packages.config -recurse | 
        Where-Object { -not ($_.PSIsContainer) } | 
        ForEach-Object {

        . $nugetExe restore $_.FullName -NonInteractive -SolutionDirectory $solutionFolder

    }
}

function Build-Nupkg {
    param(
        [string]$rootFolder = $(throw "-rootFolder is required."),
        [string]$project = $(throw "-project is required."),
        [string]$nugetExe = $(throw "-nugetExe is required."),
        [string]$outputFolder = $(throw "-outputFolder is required."),
        [string]$config = $(throw "-config is required."),
        [string]$version = $(throw "-version is required."),
        [string]$platform = $(throw "-platform is required.")
    )

    Write-Diagnostic "Creating nuget package for platform $platform"
    
    $platformOutputFolder = Join-Path $outputFolder "$config\$targetFramework"
    $outputFolder = Join-Path $outputFolder "$config"
    
    Create-Folder-Safe -folder $outputFolder
    
    # http://docs.nuget.org/docs/reference/command-line-reference#Pack_Command
    #. $nugetExe pack $nuspecFilename -OutputDirectory $outputFolder -Symbols -NonInteractive `
    . $nugetExe pack $project -OutputDirectory $outputFolder -Symbols -NonInteractive -Build `
        -Properties "Configuration=$config;Bin=$outputFolder;Platform=$platform" -Version $version

    if($LASTEXITCODE -ne 0) {
        Die("Build failed: $projectName")
    }

    # Support for multiple build runners
    if(Test-Path env:BuildRunner) {
        $buildRunner = Get-Content env:BuildRunner

        switch -Wildcard ($buildRunner.ToString().ToLower()) {
            "myget" {

                $mygetBuildFolder = Join-Path $rootFolder "Build"

                Create-Folder-Safe -folder $mygetBuildFolder

                Get-ChildItem $outputFolder -filter *.nupkg | 
                Where-Object { -not ($_.PSIsContainer) } | 
                ForEach-Object {
                    $fullpath = $_.FullName
                    $filename = $_.Name

                    cp $fullpath $mygetBuildFolder\$filename
                }
            }
        }
    }
}

function Build-Project {
    param(
        [string]$project = $(throw "-project is required."),
        [string]$outputFolder = $(throw "-outputFolder is required."),
        [string]$nugetExe = $(throw "-nugetExe is required."),
        [string]$config = $(throw "-config is required."),
        [string]$target = $(throw "-target is required."),
        [string[]]$targetFrameworks = $(throw "-targetFrameworks is required."),
        [string[]]$platform = $(throw "-platform is required.")
    )

    $projectPath = [System.IO.Path]::GetFullPath($project)
    $projectName = [System.IO.Path]::GetFileName($projectPath) -ireplace ".csproj$", ""

    Create-Folder-Safe -folder $outputFolder
    

    if(-not (Test-Path $projectPath)) {
        Die("Could not find csproj: $projectPath")
    }
    
    $targetFrameworks | foreach-object {
        $targetFramework = $_
        $platformOutputFolder = Join-Path $outputFolder "$config\$targetFramework"

        Create-Folder-Safe -folder $platformOutputFolder

        Write-Diagnostic "Build: $projectName ($platform / $config - $targetFramework)"

        & $msbuild `
            $projectPath `
            /t:$target `
            /p:Configuration=$config `
            /p:OutputPath=$platformOutputFolder `
            /p:TargetFrameworkVersion=$targetFramework `
            /p:Platform=$platform `
            /m `
            /v:M `
            /fl `
            /flp:LogFile=$platformOutputFolder\msbuild.log `
            /nr:false

        if($LASTEXITCODE -ne 0) {
            Die("Build failed: $projectName ($Config - $targetFramework)")
        }
    }
}

function Build-Solution {
    param(
        [string]$rootFolder = $(throw "-rootFolder is required."),
        [string]$solutionFile = $(throw "-solutionFile is required."),
        [string]$outputFolder = $(throw "-outputFolder is required."),
        [string]$packagesFolder = $(throw "-packagesFolder is required."),
        [string]$version = $(throw "-version is required"),
        [string]$config = $(throw "-config is required."),
        [string]$target = $(throw "-target is required."),
        [bool]$alwaysClean = $(throw "-alwaysclean is required"),
        [string[]]$targetFrameworks = $(throw "-targetFrameworks is required."),
        [string[]]$projects = $(throw "-projects is required."),
        [string[]]$platforms = $(throw "-platforms is required.")
    )

    if(-not (Test-Path $solutionFile)) {
        Die("Could not find solution: $solutionFile")
    }

    $solutionFolder = [System.IO.Path]::GetDirectoryName($solutionFile)
    $nugetExe = if(Test-Path Env:NuGet) { Get-Content env:NuGet } else { Join-Path $rootFolder "\util\nuget\nuget.exe" }

    if($alwaysClean) {
        Build-Clean -root $solutionFolder
    }

    Build-Bootstrap -solutionFile $solutionFile -nugetExe $nugetExe
    #$version = Increment-BuildNumbers

    $projects | ForEach-Object {

        $project = $_

        $platforms | ForEach-Object {
            $platform = $_
            $buildOutputFolder = Join-Path $outputFolder "$version\$platform"
            $nugetPackagesFolder = Join-Path $packagesFolder "$version\$platform"
            
            Build-Project -rootFolder $solutionFolder -project $project -outputFolder $buildOutputFolder `
                -nugetExe $nugetExe -target $target -config $config `
                -targetFrameworks $targetFrameworks -version $version -platform $platform

            Build-Nupkg -rootFolder $rootFolder -project $project -nugetExe $nugetExe -outputFolder $nugetPackagesFolder `
                -config $config -version $version -platform $platform
        }
    }
}

function TestRunner-Nunit {
    param(
        [string]$outputFolder = $(throw "-outputFolder is required."),
        [string]$config = $(throw "-config is required."),
        [string]$target = $(throw "-target is required."),
        [string[]]$projects = $(throw "-projects is required."),
        [string[]]$platforms = $(throw "-platforms is required.")
    )

    Die("TODO")
}

Function Increment-BuildNumbers
{
    Write-Diagnostic "Build: Increment Build Numbers"
    
    $assemblyPattern = "[0-9]+(\.([0-9]+|\*)){1,3}"
    $assemblyVersionPattern = 'NugetPackageVersion\("([0-9]+(\.([0-9]+|\*)){1,3})"\)'

    $projectDirectory = [System.IO.Path]::GetDirectoryName($rootFolder)
    #$versionFile = Get-ChildItem $projectDirectory\Worcom.Framework\VERSION.ver
    $versionFile = Join-Path $projectDirectory "\Worcom.Framework\VERSION.ver"

    $rawVersionNumberGroup = Get-Content $versionFile | Select-String -pattern $assemblyVersionPattern | Select -first 1 | % { $_.Matches }
    $rawVersionNumber = $rawVersionNumberGroup.Groups[1].Value
    $versionParts = $rawVersionNumber.Split('.')
    $versionParts[2] = ([int]$versionParts[2]) + 1
    $updatedAssemblyVersion = "{0}.{1}.{2}" -f $versionParts[0], $versionParts[1], $versionParts[2]
    
    Write-Diagnostic $updatedAssemblyVersion
    
    Foreach( $file in $versionFile )
    {   
        (Get-Content $file) | ForEach-Object {
                % {$_ -replace $assemblyPattern, $updatedAssemblyVersion }                 
        } | Set-Content $file                               
    }
    
    Return $updatedAssemblyVersion
}

# Bootstrap
$rootFolder = Split-Path -parent $script:MyInvocation.MyCommand.Definition
$outputFolder = Join-Path $rootFolder "artifacts\bin"
$packagesFolder = Join-Path $rootFolder "artifacts\dist"
$testsFolder = Join-Path $outputFolder "tests"
$msbuild = "C:\Program Files (x86)\MSBuild\14.0\Bin\MsBuild.exe"
$config = $config.substring(0, 1).toupper() + $config.substring(1)
$version = $config.trim()

# Myget
$currentVersion = if(Test-Path env:PackageVersion) { Get-Content env:PackageVersion } else { $packageVersion }

if($currentVersion -eq "") {
    Die("Package version cannot be empty")
}

# Build
Build-Solution -solutionFile $rootFolder\src\Worcom.Framework.sln `
    -projects @( `
        "$rootFolder\src\Worcom.Framework.AspNet.Mvc\Worcom.Framework.AspNet.Mvc.csproj",
        "$rootFolder\src\Worcom.Framework.AspNet.WebForms\Worcom.Framework.AspNet.WebForms.csproj",
        "$rootFolder\src\Worcom.Framework.BasicAuthentication\Worcom.Framework.BasicAuthentication.csproj",
        "$rootFolder\src\Worcom.Framework.Caching\Worcom.Framework.Caching.csproj",
        "$rootFolder\src\Worcom.Framework.Configuration\Worcom.Framework.Configuration.csproj",
        "$rootFolder\src\Worcom.Framework.Core\Worcom.Framework.Core.csproj",
        "$rootFolder\src\Worcom.Framework.Data\Worcom.Framework.Data.csproj",
        "$rootFolder\src\Worcom.Framework.Logger\Worcom.Framework.Logger.csproj",
        "$rootFolder\src\Worcom.Framework.DomainNotifications\Worcom.Framework.DomainNotifications.csproj",
        "$rootFolder\src\Worcom.Framework.Messaging\Worcom.Framework.Messaging.csproj" 
        "$rootFolder\src\Worcom.Framework.Native\Worcom.Framework.Native.csproj",
        "$rootFolder\src\Worcom.Framework.Net\Worcom.Framework.Net.csproj",
		"$rootFolder\src\Worcom.Framework.Mail\Worcom.Framework.Mail.csproj",
        "$rootFolder\src\Worcom.Framework.Scheduling\Worcom.Framework.Scheduling.csproj", 
        "$rootFolder\src\Worcom.Framework.Security\Worcom.Framework.Security.csproj",
        "$rootFolder\src\Worcom.Framework.Services\Worcom.Framework.Services.csproj",
        "$rootFolder\src\Worcom.Framework.Validation\Worcom.Framework.Validation.csproj"
    ) `
    -rootFolder $rootFolder `
    -outputFolder $outputFolder `
    -packagesFolder $packagesFolder `
    -platforms $platforms `
    -version $currentVersion `
    -config $config `
    -target $target `
    -targetFrameworks $targetFrameworks `
    -alwaysClean $alwaysClean