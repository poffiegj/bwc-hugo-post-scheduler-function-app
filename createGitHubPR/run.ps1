using namespace System.Net

# Input bindings are passed in via the param block.
param($Request, $TriggerMetadata)

# Convert the raw JSON body to a PowerShell object
$requestData = $Request.RawBody | ConvertFrom-Json

# JSON Export
$PublishDay = $requestData.PublishDay
$PublishTime = $requestData.PublishTime
$BlogTitle = $requestData.BlogTitle

# Verbose Message
Write-Output "Response Data:"
Write-Output "PublishDay...: $PublishDay"
Write-Output "PublishTime..: $PublishTime"
Write-Output "BlogTitle....: $BlogTitle"

# Associate values to output bindings by calling 'Push-OutputBinding'.
Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = [HttpStatusCode]::OK
        Body       = "Request Received, Awesome Work!"
    })

Write-Output "GitHub Automated Pull Request Trigger"
$GitHubAuthentication = $env:GITHUB_USER_TOKEN
$repoOwner = 'builtwithcaffeine'
$repoName = 'swa-builtwithcaffeine-dev'
$Uri = "https://api.github.com/repos/$repoOwner/$repoName/branches"
$createPullRequestUri = "https://api.github.com/repos/$repoOwner/$repoName/pulls"
$GitHubBranches = Invoke-WebRequest -Uri $Uri -Headers @{
    Authorization = "Bearer $GitHubAuthentication"
} -Method Get -UseBasicParsing -ContentType "application/json"

# Exclude the "main" branch from the list
$GitHubBranchesData = $GitHubBranches.Content | ConvertFrom-Json
$DefaultBranch = "dev-main"
$filteredBranches = $GitHubBranchesData | Where-Object { $_.name -ne $DefaultBranch }

Write-Output "" # Gap required for Clean Debugging
Write-Output "[API Check] :: Branches Found: $($filteredBranches)"

# Create pull requests for each branch
foreach ($branch in $filteredBranches) {
    $sourceBranch = $branch.name

    # Create pull request data
    $pullRequestData = @{
        title = "[AzFunction] - New Blog Post: $BlogTitle"
        body  = "PublishDay: $PublishDay, `nPublishTime: $PublishTime"
        head  = $sourceBranch
        base  = $DefaultBranch
    }

    # Convert data to JSON
    $pullRequestJson = $pullRequestData | ConvertTo-Json

    # Create pull request
    $createPullRequest = Invoke-WebRequest -Uri $createPullRequestUri -Headers @{
        Authorization = "Bearer $GitHubAuthentication"
        Accept        = "application/vnd.github.v3+json"
    } -Method Post -Body $pullRequestJson -ContentType "application/json"

    # Display the result
    $pullRequestInfo = $createPullRequest.Content | ConvertFrom-Json
    Write-Host "Pull Request created for $($branch.name). URL: $($pullRequestInfo.html_url)"
}
