# Contributing

Thanks for helping improve `toss.nvim`.

## Before you start

For a substantial change, open an issue or discussion first so the scope and
expected behavior are clear. Keep each pull request focused on one change.

## Workflow

1. Start from the latest `main` branch.
2. Create a topic branch for your change.
3. Make the smallest change that solves the problem.
4. Run the project checks locally.
5. Open a pull request against `main` and describe the change and verification.

## Checks

Run all local checks from the repository root:

```sh
make check
```

These checks do not require Herdr or a terminal pane. See
[DEVELOPMENT.md](DEVELOPMENT.md) for development setup, individual commands,
and the local Neovim workflow.

## Review and merge

Pull requests are checked by GitHub Actions and require approval from the
repository code owner, `@pedrodrocha`, before they can be merged. Keep the
branch up to date with `main` and resolve review feedback before merging.

Pull requests should include:

- a short summary of the change;
- relevant tests or checks that were run;
- any known limitations or follow-up work.
