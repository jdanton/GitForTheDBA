# Demo 2: GitHub Actions deploys a schema change to Azure SQL  (~8 minutes)
#
# Story: a developer opens a PR with a migration. The Action dry-runs it
# against the real database and catches a bug. The fix goes green, the PR is
# merged, a DBA approves the deployment, and the change is applied and audited.
# No database password exists anywhere: the runner VM uses its managed identity.

# =============================================================================
# BEFORE THE TALK (off screen)
# =============================================================================
# 1. Runner VM on and idle:
#      az vm start -g rg-github-runner-eus -n gh-runner-lnx-1
#      Settings > Actions > Runners: gh-runner-lnx-1 shows "Idle"
# 2. Infra exists (one time):  see README "Setup"  (terraform apply in infra/)
# 3. Seed 001 and wake the serverless DB (it pauses after 1 hour idle):
#      gh workflow run deploy-schema.yml --ref main
#      approve it in the browser, then:  gh run watch
# 4. az login   (your token expires every few hours; step 5 below needs it)
# 5. Browser tabs: repo > Actions, repo > Settings > Actions > Runners
# 6. Terminal:
cd $env:USERPROFILE\Documents\GitForTheDba
git switch main
git pull
$server = gh variable get SQL_SERVER
$db     = gh variable get SQL_DATABASE

# =============================================================================
# 1. Tour (1 min)
# =============================================================================
code .github/workflows/deploy-schema.yml
# Talking points:
#  - Two jobs: "plan" on pull requests, "deploy" on merge to main
#  - runs-on: self-hosted. That's gh-runner-lnx-1, a VM in OUR Azure subscription
#    (show the Runners tab). It can reach the database; GitHub's cloud can't.
#  - No secrets. The VM signs in to Azure SQL with its managed identity.
#  - scripts/migrate.sh: numbered files, applied once, logged in dbo.SchemaVersion

# =============================================================================
# 2. A migration with a bug (2 min)
# =============================================================================
git switch -c widget-price

@"
ALTER TABLE dbo.Widget
    ADD Price decimal(10,2) NOT NULL
        CONSTRAINT DF_Widget_Price DEFAULT (0);
GO

CREATE INDEX IX_Widget_Name ON dbo.Widget (Nmae);
"@ | Out-File -Encoding utf8 migrations/002_add_widget_price.sql

git add migrations
git commit -m "Add Price column and Name index to Widget"
git push -u origin widget-price
gh pr create --fill
Start-Sleep 10                  # give GitHub a moment to queue the check
gh pr checks --watch            # RED: Column name 'Nmae' does not exist

# Open the PR in the browser:  gh pr view --web
#  - The bot comment shows the failing file and the SQL error
#  - The dry run ran in a transaction that was rolled back: prod is untouched
#  - The Files tab has an error annotation on 002_add_widget_price.sql

# =============================================================================
# 3. Fix it (1 min)
# =============================================================================
(Get-Content migrations/002_add_widget_price.sql) -replace 'Nmae', 'Name' |
    Set-Content -Encoding utf8 migrations/002_add_widget_price.sql
git commit -am "Fix column name in Widget index"
git push
Start-Sleep 10
gh pr checks --watch            # GREEN. Same PR comment, now updated to pass

# =============================================================================
# 4. Merge, approve, deploy (2 min)
# =============================================================================
gh pr merge --squash --delete-branch

# Browser: Actions > "Deploy schema" run > "Waiting for review"
#  - The production environment requires a reviewer and only accepts main
#  - Click "Review deployments" > production > "Approve and deploy"
gh run watch                    # pick the running "Deploy schema" run

# Open the run: the job summary has the applied migrations and history table

# =============================================================================
# 5. Proof (1 min)
# =============================================================================
git switch main
git pull

sqlcmd -S $server -d $db --authentication-method ActiveDirectoryDefault -Q "
SELECT ScriptName, AppliedUtc, AppliedBy, GitHubActor, LEFT(CommitSha, 7) AS CommitSha
FROM dbo.SchemaVersion ORDER BY AppliedUtc;

SELECT * FROM dbo.Widget;"
#  - AppliedBy is the runner's managed identity; GitHubActor is who merged
#  - CommitSha links each schema change back to the PR that made it

# =============================================================================
# BONUS, if there's time (1 min): try to rewrite history
# =============================================================================
git switch -c sneaky-edit
Add-Content migrations/001_create_widget.sql "-- just a small tweak"
git commit -am "Tweak an applied migration"
git push -u origin sneaky-edit
gh pr create --fill
Start-Sleep 10
gh pr checks --watch            # RED: 001 was already applied and has changed
gh pr close --delete-branch
git switch main
git branch -D sneaky-edit

# =============================================================================
# RESET AFTER A REHEARSAL
# =============================================================================
# Remove 002 from main (the deploy that this push triggers has nothing to do):
#   git rm migrations/002_add_widget_price.sql
#   git commit -m "Reset demo"
#   git push
# Undo it in the database:
#   sqlcmd -S $server -d $db --authentication-method ActiveDirectoryDefault -Q "
#   DROP INDEX IF EXISTS IX_Widget_Name ON dbo.Widget;
#   ALTER TABLE dbo.Widget DROP CONSTRAINT IF EXISTS DF_Widget_Price;
#   ALTER TABLE dbo.Widget DROP COLUMN IF EXISTS Price;
#   DELETE dbo.SchemaVersion WHERE ScriptName = N'002_add_widget_price.sql';"
