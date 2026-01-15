# Git Hooks

## Pre-commit Hook

This pre-commit hook performs automatic formatting and checks before finalizing your commit.

### What it does

1. **Runs `moon fmt`** - Automatically formats your MoonBit code according to the project's style guide
2. **Runs `moon check`** - Performs static analysis to catch common errors

This ensures that all committed code is properly formatted and passes basic checks before being pushed to the repository.

### Usage Instructions

To use this pre-commit hook:

1. Make the hook executable if it isn't already:
   ```bash
   chmod +x .githooks/pre-commit
   ```

2. Configure Git to use the hooks in the .githooks directory:
   ```bash
   git config core.hooksPath .githooks
   ```

3. The hook will automatically run when you execute `git commit`

### Troubleshooting

If you need to bypass the pre-commit hook (not recommended), you can use:
```bash
git commit --no-verify
```

However, this should only be used in exceptional circumstances, as it may introduce improperly formatted code or violations that could cause CI to fail.
