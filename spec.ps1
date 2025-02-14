# Version 1.6

# AssemblyInfo 속성 조회
function GetValue{
    param($line)
    $property = $line.ToString()
    $first = $property.IndexOf('"') + 1
    $last = $property.LastIndexOf('"')
    return $property.SubString($first, $last - $first)
}

$file = (Get-ChildItem -Path . -Filter *.nuspec)[0]
$spec = [xml](Get-Content $file)

$removeds = @()

# 의존 관계 패키지 등록
$files = Get-ChildItem -Path $args[0] -Filter 'packages.config' -Recurse
$packages = @()
foreach ($config in $files) {
    $xml = [xml](Get-Content $config.FullName)
    $packs = $xml.GetElementsByTagName("package")
    foreach ($pack in $packs) {
        $packages+=$pack
     }
}
if ($packages.Count -gt 0) {
	foreach ($package in $packages){
        $exist = ($spec.package.metadata.dependencies.dependency | where {$_.id -eq $package.id})
        if ($exist -eq $null) {
			$element = $spec.CreateElement("dependency")
			$id = $spec.CreateAttribute("id");
			$id.Value = $package.id
			$version = $spec.CreateAttribute("version")
			$version.Value = $package.version
			$element.Attributes.Append($id)
			$element.Attributes.Append($version)
			$spec.package.metadata.dependencies.AppendChild($element)
		}
    }
    $spec.package.metadata.dependencies.RemoveChild($spec.package.metadata.dependencies.FirstChild)
}else{
	$removeds+=$spec.package.metadata.dependencies
}

# 삭제할 태그 등록 및 삭제
foreach ($node in $spec.package.metadata.ChildNodes){
	if ($node.Name.EndsWith('Url')){
        $removeds+=$node
    }
}
if( $removeds.Count -igt 0) {
    foreach ($node in $removeds) {
        $node.ParentNode.RemoveChild($node)
    }
}

# 제목 태그가 없는 경우 추가
if($spec.package.metadata.Item('title') -eq $null) {
    $spec.package.metadata.InsertAfter($spec.CreateElement("title"), $spec.package.metadata.Item('version'))
}

# 패키지 Id 조회
$solutions = Get-ChildItem -Path $args[0] -Filter *.sln -Recurse
if ($solutions -eq $null){
	$project = ([xml](Get-Content (Get-ChildItem -Path $args[0] -Filter *proj -Recurse)[0].FullName)).GetElementsByTagName('RootNamespace')[0].InnerText
}else{
	$project = [io.path]::GetFileNameWithoutExtension($solutions[0].Name)
}
$spec.package.metadata.id = $project

# 패키지 속성 매핑
$headliners = Get-ChildItem -Path $args[0] -Filter "Description.txt" -Recurse
if ($headliners -ne $null) {
	$description = Get-Content $headliners[0].FullName
	$headliner = Split-Path -Path $headliners[0].FullName
}
$tags = ""
if ($headliner -eq $null) {
	$headliner = $args[0]
}
Get-Content (Get-ChildItem -Path $headliner -Filter "AssemblyInfo.cs" -Recurse)[0].FullName | ForEach-Object {
    if ($_ -like '*Title*') {
		if ($solutions -eq $null){
			$spec.package.metadata.title = GetValue -line $_
		}
    }
    if ($_ -like '*Company*'){
        $company = GetValue -line $_
        $spec.package.metadata.authors = $company
        $spec.package.metadata.owners = $company
    }
    if ($_ -like '*Description*') {
		if ($description -eq $null){
			$spec.package.metadata.description = GetValue -line $_
		}else{
			$spec.package.metadata.description = [string]$description
		}
    }
    if ($_ -like '*Copyright*') {
        $spec.package.metadata.copyright = GetValue -line $_
    }
    if ($_ -like '*AssemblyFileVersion*') {
		if ($solutions -ne $null){
			$spec.package.metadata.version = GetValue -line $_
		}
    }
	if ($_ -like '*AssemblyVersion*') {
		if ($solutions -eq $null){
			$spec.package.metadata.version = GetValue -line $_
		}
	}
	if ($_ -like '*Product*') {
		if ($solutions -ne $null) {
			$spec.package.metadata.title = GetValue -line $_
		}
	}
	if ($_ -like '*TradeMark*') {
		$tags = GetValue -line $_
	}
}
$spec.package.metadata.tags = $tags

# 버전관리 로그 조회
$OutputEncoding = [Console]::OutputEncoding
$output = (변경 기록 조회 명령: (Subversion) svn log (버전관리 주소)/$($args[1]), (Git) git log -1) | Out-String
$logs = $output -split '\n'
$count = 0
foreach ($log in $logs){
	$text = $log -replace '\r', ""
	$count++
	if ($count -lt 4) { continue }
	if ($text.StartsWith('------')) { break }
	if ([string]::IsNullOrEmpty($text)) { break }
	if ([string]::IsNullOrEmpty($message)) {}
	else { $message += ', ' }
	$message += $text
}
if ([string]::IsNullOrEmpty($message)) { $message = "최신 수정 기록 없음" }
$spec.package.metadata.releaseNotes = $message

$spec.Save($file)
