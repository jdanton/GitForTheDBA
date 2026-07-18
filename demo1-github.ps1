# --- Slide 9: create a repo ---
cd $env:USERPROFILE\Documents
git init GitForTheDba
cd GitForTheDba
git status                      # nothing staged, on branch main

# --- Slide 10: first commits ---
# Create a couple of DBA-flavored files
@"
# Git for the DBA
Sample schema repo for the talk.
"@ | Out-File -Encoding utf8 README.md

@"
CREATE TABLE dbo.Widget (
    WidgetId INT IDENTITY(1,1) PRIMARY KEY,
    Name     NVARCHAR(100) NOT NULL
);
"@ | Out-File -Encoding utf8 001_create_widget.sql

git add .
git status                      # both files staged (green)
git commit -m "Initial schema and readme"
git log --oneline               # one commit

# Make a second change so history isn't trivial
"    CreatedUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()" |
    Add-Content 001_create_widget.sql
git add 001_create_widget.sql
git commit -m "Add audit column to Widget"
git log --oneline               # two commits now

# --- Connect to GitHub ---
git remote add origin https://github.com/jdanton/GitForTheDba.git
git branch -M main              # ensure branch is 'main', not 'master'
git push -u origin main
# Refresh the GitHub page — both commits are now there

# --- Pull, fetch, merge ---
# Simulate a teammate: edit README.md in the GitHub web UI and commit.
# Back in the terminal:
git fetch                       # downloads the change, working tree untouched
git status                      # "Your branch is behind 'origin/main' by 1 commit"
git log --oneline origin/main   # you can see the remote commit before merging
git merge origin/main           # fast-forward merge into local main
# (or do both at once:)
git pull                        # fetch + merge in one step
git log --oneline               # local history now includes the teammate's commit