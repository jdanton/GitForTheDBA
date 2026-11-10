#!/usr/bin/env bash
#
# migrate.sh - apply numbered SQL migrations to an Azure SQL Database.
#
#   migrate.sh plan    Dry run. Executes every pending migration inside ONE
#                      transaction and then rolls it back. SQL Server DDL is
#                      transactional, so this proves the scripts compile and
#                      run against the real schema without changing anything.
#
#   migrate.sh apply   Applies each pending migration in its own transaction
#                      and records it in dbo.SchemaVersion (same transaction),
#                      so a migration is either fully applied and logged, or
#                      not applied at all.
#
# A migration is any migrations/NNN_description.sql file, applied in name order.
# An applied migration is never re-run. If its contents change afterwards the
# script refuses to continue: write a new migration instead of editing history.
#
# Environment:
#   SQL_SERVER, SQL_DATABASE  required
#   SQL_AUTH                  sqlcmd --authentication-method. Default is
#                             ActiveDirectoryManagedIdentity (the runner VM's
#                             identity, no password anywhere). On a laptop,
#                             use ActiveDirectoryDefault after `az login`.
#   MIGRATIONS_DIR            default: migrations
#   REPORT_FILE               markdown report output (default: migration-report.md)
#
set -euo pipefail
export LC_ALL=C                      # stable, byte-wise sort order for file names

mode="${1:-}"
case "$mode" in
  plan|apply) ;;
  *) echo "usage: $0 plan|apply" >&2; exit 2 ;;
esac

: "${SQL_SERVER:?SQL_SERVER is not set}"
: "${SQL_DATABASE:?SQL_DATABASE is not set}"
auth="${SQL_AUTH:-ActiveDirectoryManagedIdentity}"
dir="${MIGRATIONS_DIR:-migrations}"
report="${REPORT_FILE:-migration-report.md}"
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"

actor="${GITHUB_ACTOR:-$(whoami)}"
commit="${GITHUB_SHA:-$(git rev-parse HEAD 2>/dev/null || echo unknown)}"
run_url=""
if [[ -n "${GITHUB_RUN_ID:-}" ]]; then
  run_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# -b: exit non-zero on the first SQL error.  -x: don't treat $(...) in a
# migration as a sqlcmd variable.  -l 60: give a paused serverless DB time to wake.
sql() {
  sqlcmd -S "$SQL_SERVER" -d "$SQL_DATABASE" --authentication-method "$auth" -b -x -l 60 "$@"
}

sha256() {
  if command -v sha256sum >/dev/null; then sha256sum "$1"; else shasum -a 256 "$1"; fi | cut -d' ' -f1
}

# Escape a value for use inside an N'...' literal.
q() { printf '%s' "${1//\'/\'\'}"; }

# Copy a migration into the work dir without a UTF-8 BOM (Windows PowerShell 5
# adds one), so it can be safely :r-included in the middle of a wrapper script.
staged() {
  local out="$work/$(basename "$1")"
  if [[ "$(head -c3 "$1" | od -An -tx1 | tr -d ' \n')" == "efbbbf" ]]; then
    tail -c +4 "$1" > "$out"
  else
    cp "$1" "$out"
  fi
  printf '%s' "$out"
}

out() { printf '%s\n' "$*" >> "$report"; }
: > "$report"

# --- What has already been applied? -----------------------------------------
sql -h -1 -W -Q "SET NOCOUNT ON;
  IF OBJECT_ID(N'dbo.SchemaVersion', N'U') IS NOT NULL
    SELECT ScriptName + N'|' + Checksum FROM dbo.SchemaVersion;" \
  | tr -d '\r' > "$work/applied.txt"

shopt -s nullglob
files=("$dir"/[0-9]*_*.sql)

pending=()
drift=()
applied_count=0
for f in ${files[@]+"${files[@]}"}; do
  name="$(basename "$f")"
  sum="$(sha256 "$f")"
  recorded="$(awk -F'|' -v n="$name" '$1 == n { print $2 }' "$work/applied.txt")"
  if [[ -z "$recorded" ]]; then
    pending+=("$f")
  elif [[ "$recorded" != "$sum" ]]; then
    drift+=("$f")
  else
    applied_count=$((applied_count + 1))
  fi
done

title="Schema plan (dry run)"
[[ "$mode" == apply ]] && title="Schema deployment"
out "## $title: \`$SQL_DATABASE\`"
out ""
out "Server \`$SQL_SERVER\` · commit \`${commit:0:7}\` · $applied_count already applied · ${#pending[@]} pending"
out ""

# --- Refuse to continue if history was rewritten -----------------------------
if (( ${#drift[@]} > 0 )); then
  out "### ❌ Applied migrations were edited"
  out ""
  out "These files were already applied, but their contents changed since then:"
  out ""
  for f in "${drift[@]}"; do
    out "- \`$(basename "$f")\`"
    echo "::error file=$f::$(basename "$f") was already applied to $SQL_DATABASE, but its contents changed. Revert it and write a new migration instead."
  done
  out ""
  out "Revert the edit and put the change in a new migration file."
  cat "$report" >> "$summary"
  exit 1
fi

if (( ${#pending[@]} == 0 )); then
  out "### ✅ Nothing to do"
  out ""
  out "The database already matches the repo."
  cat "$report" >> "$summary"
  exit 0
fi

out "| Migration | SHA-256 |"
out "|---|---|"
for f in "${pending[@]}"; do
  out "| \`$(basename "$f")\` | \`$(sha256 "$f" | cut -c1-12)\` |"
done
out ""

# Write a failure section that names the file and shows the SQL error.
failed() {
  local f="$1" log="$2"
  echo "::error file=$f::$(basename "$f") failed. See the job log for the SQL error."
  out "### ❌ \`$(basename "$f")\` failed"
  out ""
  out '```text'
  grep -v '^>>> ' "$log" | tail -n 15 >> "$report"
  out '```'
}

# --- plan: run everything in one transaction, then roll back -----------------
if [[ "$mode" == plan ]]; then
  {
    echo "SET XACT_ABORT ON;"
    echo "SET NOCOUNT ON;"
    echo "BEGIN TRANSACTION;"
    echo "GO"
    for f in "${pending[@]}"; do
      echo "PRINT N'>>> $(q "$(basename "$f")")';"
      echo "GO"
      echo ":r $(staged "$f")"
      echo "GO"
    done
    echo "IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;"
    echo "PRINT N'>>> rolled back';"
  } > "$work/plan.sql"

  if sql -i "$work/plan.sql" > "$work/plan.log" 2>&1; then
    cat "$work/plan.log"
    out "### ✅ Dry run succeeded"
    out ""
    out "Every pending migration ran against \`$SQL_DATABASE\` and was then rolled back. Nothing changed."
    out "Merging this PR will apply them."
    cat "$report" >> "$summary"
    exit 0
  fi

  cat "$work/plan.log"
  last="$(grep '^>>> ' "$work/plan.log" | tail -n1 | sed 's/^>>> //')"
  failed "$dir/${last:-unknown}" "$work/plan.log"
  out "The transaction was rolled back. Nothing changed in \`$SQL_DATABASE\`."
  cat "$report" >> "$summary"
  exit 1
fi

# --- apply: one transaction per migration, logged in dbo.SchemaVersion -------
sql -Q "
IF OBJECT_ID(N'dbo.SchemaVersion', N'U') IS NULL
CREATE TABLE dbo.SchemaVersion
(
    ScriptName   nvarchar(260) NOT NULL CONSTRAINT PK_SchemaVersion PRIMARY KEY,
    Checksum     char(64)      NOT NULL,
    AppliedUtc   datetime2(0)  NOT NULL CONSTRAINT DF_SchemaVersion_AppliedUtc DEFAULT SYSUTCDATETIME(),
    AppliedBy    sysname       NOT NULL CONSTRAINT DF_SchemaVersion_AppliedBy  DEFAULT SUSER_SNAME(),
    GitHubActor  nvarchar(100) NULL,
    CommitSha    varchar(40)   NULL,
    RunUrl       nvarchar(400) NULL
);"

for f in "${pending[@]}"; do
  name="$(basename "$f")"
  echo "==> Applying $name"
  {
    echo "SET XACT_ABORT ON;"
    echo "SET NOCOUNT ON;"
    echo "BEGIN TRANSACTION;"
    echo "GO"
    echo ":r $(staged "$f")"
    echo "GO"
    echo "INSERT dbo.SchemaVersion (ScriptName, Checksum, GitHubActor, CommitSha, RunUrl)"
    echo "VALUES (N'$(q "$name")', '$(sha256 "$f")', N'$(q "$actor")', '$(q "$commit")', N'$(q "$run_url")');"
    echo "COMMIT TRANSACTION;"
    echo "GO"
  } > "$work/apply.sql"

  if ! sql -i "$work/apply.sql" > "$work/apply.log" 2>&1; then
    cat "$work/apply.log"
    failed "$f" "$work/apply.log"
    out "\`$name\` was rolled back. Migrations listed before it are committed."
    cat "$report" >> "$summary"
    exit 1
  fi
  cat "$work/apply.log"
done

out "### ✅ Applied ${#pending[@]} migration(s)"
out ""
out "Recent history from \`dbo.SchemaVersion\`:"
out ""
out "| Migration | Applied (UTC) | By | Commit |"
out "|---|---|---|---|"
sql -h -1 -W -s '|' -Q "SET NOCOUNT ON;
  SELECT TOP (10) ScriptName, CONVERT(varchar(19), AppliedUtc, 120),
         ISNULL(GitHubActor, AppliedBy), LEFT(ISNULL(CommitSha, ''), 7)
  FROM dbo.SchemaVersion
  ORDER BY AppliedUtc DESC, ScriptName DESC;" \
  | tr -d '\r' | sed '/^$/d; s/^/| /; s/$/ |/; s/|/ | /g; s/  */ /g; s/^ //; s/ $//' >> "$report"

cat "$report" >> "$summary"
echo "All pending migrations applied."
