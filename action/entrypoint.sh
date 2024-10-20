#!/bin/sh -l

# Function to run Replexica CLI
run_replexica() {
    npx replexica@${REPLEXICA_VERSION} i18n
    if [ $? -eq 1 ]; then
        echo "::error::Replexica: Translation update failed. For assistance, send our CTO an email to max@replexica.com."
        exit 1
    fi
}

# Function to configure git
configure_git() {
    git config --global --add safe.directory $PWD
    git config --global user.name "Replexica"
    git config --global user.email "support@replexica.com"
}

# Function to get the current branch name
get_current_branch() {
    local branch_name=""

    if [ -n "$GITHUB_HEAD_REF" ]; then
        # Pull request
        branch_name="$GITHUB_HEAD_REF"
    elif [ -n "$GITHUB_REF_NAME" ]; then
        # Push or workflow_dispatch
        if echo "$GITHUB_REF" | grep -q "^refs/tags/"; then
            # It's a tag, return the default branch
            branch_name=$(gh api repos/:owner/:repo | jq -r .default_branch)
        else
            branch_name="$GITHUB_REF_NAME"
        fi
    elif [ -n "$GITHUB_REF" ]; then
        # Fallback for other cases
        branch_name=$(echo "$GITHUB_REF" | sed 's:^refs/[^/]*/::')
    else
        echo "::error::Replexica: Unable to determine the current branch name. For assistance, send our CTO an email to max@replexica.com."
        exit 1
    fi

    echo "$branch_name"
}

# Function to commit changes
commit_changes() {
    git add .
    if ! git diff --staged --quiet; then
        git commit -m "${REPLEXICA_COMMIT_MESSAGE}"
        echo "Changes committed successfully"
        return 0
    else
        echo "::notice::Replexica: All translations are up to date."
        return 1
    fi
}

# Function to create or update PR
create_or_update_pr() {
    local current_branch=$(get_current_branch)
    local pr_branch="replexica/${current_branch}"
    local pr_title="${REPLEXICA_PULL_REQUEST_TITLE}"

    # Create or update the branch
    git checkout -B "$pr_branch"
    git push -f origin "$pr_branch"

    # # Check if PR already exists
    # existing_pr=$(gh pr list --head "$pr_branch" --json number --jq '.[0].number')

    # Read PR body from adjacent file called pr.md
    pr_body_file="/pr.md"

    # # PR arguments - must create pr into the current branch
    # local pr_create_args="--title \"$pr_title\" --body-file \"$pr_body_file\" --head \"$pr_branch\" --base \"$current_branch\""
    # local pr_edit_args="--title \"$pr_title\" --body-file \"$pr_body_file\""

    # # Create new PR or update existing one
    # if [ -n "$existing_pr" ]; then
    #     eval gh pr edit "$existing_pr" $pr_edit_args
    #     echo "::notice::Replexica: Updated existing PR #$existing_pr with translations. Review it here: https://github.com/$GITHUB_REPOSITORY/pull/$existing_pr"
    # else
    #     add_assignees_to_pr_args
    #     add_labels_to_pr_args "$existing_pr"

    #     new_pr=$(eval gh pr create $pr_create_args)

    #     echo "::notice::Replexica: Created new PR with translations. Review it here: $new_pr"
    # fi

    # Try creating a PR

    new_pr=$(eval gh pr create --base "$current_branch" --head "$pr_branch" --title "\"$pr_title\"" --body-file "$pr_body_file" 2>&1)

    exit_code=$?

    if [ $exit_code -eq 0 ] && [ -n "$new_pr" ]; then
      echo "Created new PR with translations. Review it here: $new_pr"
    else
      echo $new_pr
    fi
}

check_skip_i18n() {
    local commit_message="$REPLEXICA_COMMIT_MESSAGE"

    if [[ "$commit_message" =~ \[\ *[sS][kK][iI][pP]\ +[iI]18[nN]\ *\] ]]; then
        echo "::notice::i18n processing has been skipped due to '[skip i18n]' found in the commit message."
        exit 0
    fi
}

# Main execution
main() {
    # Configure git for committing changes
    configure_git

    if [ "$REPLEXICA_PULL_REQUEST" = "true" ]; then
        if [ -z "$GH_TOKEN" ]; then
            echo "::error::Replexica: GitHub token is missing. Add 'GH_TOKEN: \${{ github.token }}' to your Replexica action configuration env section."
            exit 1
        fi
    fi

    # Check commit message for skip i18n
    check_skip_i18n

    # Run Replexica to update translations
    run_replexica

    # Commit changes if any are found
    if commit_changes; then
        if [ "$REPLEXICA_PULL_REQUEST" = "true" ]; then
            # Create or update pull request
            create_or_update_pr
        else
            # Push changes to the current branch
            git push origin HEAD:$(get_current_branch)
            COMMIT_HASH=$(git rev-parse HEAD)
            COMMIT_URL="https://github.com/$GITHUB_REPOSITORY/commit/$COMMIT_HASH"
            echo "::notice::Replexica: Translation updates pushed successfully. View the commit: $COMMIT_URL"
        fi
    fi
}

# Run the main function
main
