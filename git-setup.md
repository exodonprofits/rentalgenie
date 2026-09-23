# Publishing this folder to GitHub

Run these from the project folder (the one holding `index.html`).

```bash
# 1. Copy README.md, LICENSE, .gitignore and docs/ into this folder first.

# 2. Remove private data from the working folder (keep your own copy elsewhere).
#    mortgage statements, rent exports and similar must not be committed.
mkdir -p ~/rental-genie-private
mv "import export" ~/rental-genie-private/   # optional: .gitignore also excludes it

# 3. Start the repository
git init
git add .
git status          # read this list before committing

# 4. Confirm nothing private slipped in
git status --porcelain | grep -iE "\.csv|import export|\.env" && echo "STOP: private file staged"

git commit -m "Rental Genie: initial commit"

# 5. Create a PRIVATE repo on GitHub, then:
git remote add origin git@github.com:<you>/rental-genie.git
git branch -M main
git push -u origin main
```

## Make it private

The repository holds the full product and one live portfolio's structure. Choose **Private** when
creating it on GitHub. If it is ever made public by accident, rotate the Supabase anon key
afterwards, even though row-level security protects the data.

## If a secret is ever committed

Deleting the file in a later commit does not remove it from history. Rotate the exposed key first,
then rewrite history with `git filter-repo` before the repository is shared.

## Suggested commit hygiene

- One page per commit where practical; these files are large and diffs get unreadable otherwise.
- Prefix database work with `db:` so schema changes are easy to find later.
- Tag a release before large refactors, so reverting is one command.
