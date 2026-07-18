# Git for the DBA

A hands-on demo repo for the **"Git for the DBA"** talk. It walks database
professionals from `git init` all the way to running SQL deployments on a
self-hosted GitHub Actions runner — no prior Git experience assumed.

If you manage schema, migrations, or deployment scripts and version control
still feels like a developer thing, this repo is the guided tour.

## What you'll learn

- The core Git loop: `init`, `status`, `add`, `commit`, `log`
- Connecting a local repo to GitHub and pushing your first commits
- Staying in sync with a team: `fetch`, `merge`, and `pull`
- Automating schema deployments with GitHub Actions
- Standing up a self-hosted runner on Azure so your pipeline can reach a
  database that lives behind your firewall

## Repo contents

| File | What it is |
| --- | --- |
| [demo1-github.sh](demo1-github.sh) | Slide-by-slide walkthrough of Git basics → first push to GitHub. **PowerShell**, despite the `.sh` name (see note below). |
| [demo2-actions.sh](demo2-actions.sh) | Placeholder for the GitHub Actions portion of the demo. |
| [create-runner-vm.sh](create-runner-vm.sh) | Bash script that spins up an Azure VM and registers it as a self-hosted Actions runner. |
| [001_create_widget.sql](001_create_widget.sql) | The sample migration created live during Demo 1. |

## Prerequisites

- [Git](https://git-scm.com/downloads)
- A [GitHub](https://github.com) account
- For the runner demo: the [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
  (`az login` first) and an Azure subscription you can create resources in

## Demo 1 — Git fundamentals

> **Heads up:** `demo1-github.sh` is written in **PowerShell** (it uses
> `$env:USERPROFILE`, `Out-File`, `Add-Content`, and here-strings), so run it on
> Windows PowerShell — not `bash`. The `.sh` extension is a leftover; the Git
> commands themselves are identical on every platform.

The script is organized as copy-paste steps that mirror the talk's slides:

1. **Create a repo** — `git init`, then `git status` to see a clean tree.
2. **First commits** — write a `README.md` and `001_create_widget.sql`, stage
   them, and commit. Add an audit column in a second commit so history isn't
   trivial.
3. **Connect to GitHub** — `git remote add origin`, rename the branch to `main`,
   and `git push -u origin main`.
4. **Sync with a teammate** — edit a file in the GitHub web UI, then
   `git fetch` / `git merge` (or `git pull`) to bring the change down locally.

Work through it a block at a time rather than running the whole file at once —
the point is to watch what each command does to `git status` and `git log`.

## Demo 2 — GitHub Actions

`demo2-actions.sh` is currently a placeholder. The intent is to add a workflow
that runs the numbered `.sql` migrations against a target database whenever
changes are pushed — executed by the self-hosted runner from the next section.

## Setting up a self-hosted runner (Azure)

A self-hosted runner lets your Actions workflow reach a database that isn't
exposed to GitHub's hosted runners. `create-runner-vm.sh` automates the whole
thing: resource group → VM → runner install → systemd service.

```bash
# 1. Get a registration token from your repo:
#    Settings → Actions → Runners → New self-hosted runner
export RUNNER_TOKEN="<your-registration-token>"
export GITHUB_URL="https://github.com/<owner>/<repo>"

# 2. Create the VM and register the runner
./create-runner-vm.sh
```

The script creates a `Standard_D2s_v5` Ubuntu 22.04 VM in `eastus2`, opens **no**
inbound ports (a runner only needs outbound HTTPS), and installs the runner as a
service so it survives reboots.

> **Note:** GitHub runner registration tokens expire after about an hour, so
> generate a fresh one right before you run the script and pass it via
> `RUNNER_TOKEN`. Don't commit tokens to the repo.

### Cleanup

The runner VM costs money while it exists. Tear the whole thing down with:

```bash
az group delete --name rg-github-runner --yes --no-wait
```

## About the sample schema

`001_create_widget.sql` uses the common convention of **numbered, forward-only
migration files** — each change gets the next number, and files are applied in
order. It starts as a simple `Widget` table and gains an audit column in a
second commit, giving you a small but real history to explore with `git log`
and `git diff`.
