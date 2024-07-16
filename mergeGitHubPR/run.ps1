# Input bindings are passed in via param block.
param($Timer)

function Parse-JsonBody {
    param (
        [string]$body
    )

    # Split the body into lines and clean up unnecessary characters
    $lines = $body -split "`r?`n"

    # Create variables to store key-value pairs
    $PublishDay = $null
    $PublishTime = $null

    # Iterate through each line and split based on ":"
    foreach ($line in $lines) {
        if ($line -match '^(.+?):\s*(.+?)(,|\s*$)') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().TrimEnd(',')

            Write-Output "KeyData: $key"
            Write-Output "ValueData: $value"

            switch ($key) {
                "PublishDay" { $PublishDay = $value }
                "PublishTime" { $PublishTime = $value }
            }
        }
    }

    # Optionally, you can return or use the parsed values
    return @{
        PublishDay  = $PublishDay
        PublishTime = $PublishTime
    }
}

#
$gitHubAuthentication = $env:GITHUB_USER_TOKEN

# Get Open Pull Requests
$Uri = 'https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/pulls?state=open'
$gitHubPROpen = Invoke-WebRequest -Uri $Uri -Headers @{Authorization = "bearer $gitHubAuthentication" } -Method Get -UseBasicParsing -ContentType "application/json"

# Convert the JSON response to a PowerShell object
$PullRequests = $gitHubPROpen | ConvertFrom-Json

# Check if there are any open pull requests
if ($PullRequests.Count -eq 0) {
    Write-Output "No Pending Pull Requests, You might want to Blog again soon??"
}
else {
    # Iterate through each open pull request and display ID, message, and time
    $day = get-date -Format dddd
    Write-Output "> [$day] :: Open Pull Requests:`r"

    foreach ($pullRequest in $PullRequests) {
        $id = $pullRequest.id
        $number = $pullRequest.number
        $title = $pullRequest.title
        $body = $pullRequest.body

        # # Output the details for each pull request
        Write-Output "Pull Request Number........: $number"
        Write-Output "Pull Request Commit Id.....: $id"
        Write-Output "Pull Request Post Title....: $title"

        $postMetaData = Parse-JsonBody -body $body
        Write-Output "Pull Request Post Day......: $($postMetaData.PublishDay)"
        Write-Output "Pull Request Publish Time..: $($postMetaData.PublishTime)" `r
    }

    foreach ($pullRequest in $PullRequests) {

        $id = $pullRequest.id
        $number = $pullRequest.number
        $title = $pullRequest.title
        $body = $pullRequest.body
        $postMetaData = Parse-JsonBody -body $body

        # Pull Request Logic Time!
        Write-Output "Checking Pull Request MetaData... and Merging if needed!" `r
        If ($postMetaData.PublishTime -eq 'Now') {
            Write-Output "PublishTime is: [NOW]"
            Write-Output "Merging PR: $number - $title"

            # Add a comment to the PR
            $CommentUri = "https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/issues/$number/comments"
            $commentBody = @{
                body = "Publish Time Matched! - [$($postMetaData.PublishTime)] Closing PR ✅"
            } | ConvertTo-Json
            $gitHubPRUpdate = Invoke-WebRequest -Uri $CommentUri -Method Post -Headers @{Authorization = "Bearer $gitHubAuthentication" } -ContentType "application/json" -Body $commentBody

            # Close the PR
            $MergeUri = "https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/pulls/$number/merge"
            $jsonBody = @{
                "merge_method"   = "merge"
                "commit_title"   = "Merged PR #$number"
                "commit_message" = "[LGTM]"
            } | ConvertTo-Json
            $gitHubPRClose = Invoke-WebRequest -Uri $MergeUri -Method Put -Headers @{Authorization = "Bearer $gitHubAuthentication" } -ContentType "application/json" -Body $jsonBody

            Write-Output "Pull Request Merged, Github Action will publish the Post!"
        }

        If ($postMetaData.PublishTime -ne "Now") {
            Write-Output "Checking PublishDay [$($postMetaData.PublishDay)] for PR: $number - $title"
            If ($postMetaData.PublishDay -match (Get-Date).DayOfWeek) {
                Write-Output "Today is the day: $($(Get-Date).DayOfWeek)!"

                Write-Output `r "Checking PublishTime [$($postMetaData.PublishTime)] for PR: $number - $title..."
                $realTime = Get-Date -Format "HH:mm"
                If ($postMetaData.PublishTime -match $realTime) {
                    Write-Output "Today is the day to merge the PR! and Time is: $($postMetaData.PublishTime)"

                    # Add a comment to the PR
                    $CommentUri = "https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/issues/$number/comments"
                    $commentBody = @{
                        body = "Publish Day Matched! - [$($postMetaData.PublishDay)] `nPublish Time Matched! - [$($postMetaData.PublishTime)] `nClosing PR ✅"
                    } | ConvertTo-Json
                    $gitHubPRUpdate = Invoke-WebRequest -Uri $CommentUri -Method Post -Headers @{Authorization = "Bearer $gitHubAuthentication" } -ContentType "application/json" -Body $commentBody

                    # Close the PR
                    $MergeUri = "https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/pulls/$number/merge"
                    $jsonBody = @{
                        "merge_method"   = "merge"
                        "commit_title"   = "Merged PR #$number"
                        "commit_message" = "[LGTM]"
                    } | ConvertTo-Json
                    $gitHubPRClose = Invoke-WebRequest -Uri $MergeUri -Method Put -Headers @{Authorization = "Bearer $gitHubAuthentication" } -ContentType "application/json" -Body $jsonBody

                    Write-Output "Pull Request Merged, Github Action will publish the Post!"
                }
                else {
                    Write-Output "Today IS the day! But the time is not right for the PR Merge! and Time is: [$realTime], `n[AzFunc] - mergePR Script - Adding comment to the PR for tracking!"

                    # Add a comment to the PR
                    $timeStamp = Get-Date -Format "HH:mm"
                    $CommentUri = "https://api.github.com/repos/builtwithcaffeine/swa-builtwithcaffeine-dev/issues/$number/comments"
                    $commentBody = @{
                        body = " ⚠️ - [AzFunc] - mergePR Script - ⚠️ `nFunction Trigger Time: $timeStamp `nbut the [Time] is not right for the PR Merge! `nPublish Day - [$($postMetaData.PublishDay)] `nPublish Time - [$($postMetaData.PublishTime)] `nAzFunction will retry soon! 👋"
                    } | ConvertTo-Json
                    $gitHubPRUpdate = Invoke-WebRequest -Uri $CommentUri -Method Post -Headers @{Authorization = "Bearer $gitHubAuthentication" } -ContentType "application/json" -Body $commentBody
                }
            }
        }
    }
}