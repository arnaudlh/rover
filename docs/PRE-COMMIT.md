# Pre-commit Hooks

This document describes the pre-commit hooks configured in the rover project to ensure code quality and consistency.

## Setup

1. Install pre-commit:
```bash
pip install pre-commit
```

2. Install the git hooks:
```bash
pre-commit install
```

## Configured Hooks

### Code Quality Checks
```yaml
- id: trailing-whitespace
  # Removes trailing whitespace
- id: end-of-file-fixer
  # Ensures files end with a newline
- id: check-yaml
  # Validates YAML syntax
- id: check-added-large-files
  # Prevents large files from being committed
- id: detect-private-key
  # Checks for committed private keys
- id: check-executables-have-shebangs
  # Ensures executable files have shebangs
```

### Docker Validation
```yaml
- id: docker-compose-check
  # Validates docker-compose.yml files
  files: docker-compose\.ya?ml$
```

### Shell Script Checks
```yaml
- id: shellcheck
  # Checks shell scripts for common issues
  args: ["--severity=warning"]
```

### Dockerfile Linting
```yaml
- id: hadolint
  # Lints Dockerfiles for best practices
  args: ["--ignore=DL3008", "--ignore=DL3013"]
  files: Dockerfile.*
```

## Troubleshooting

### Common Issues

1. Hook installation fails:
```bash
# Ensure you have Python and pip installed
python -m pip install --upgrade pip
pip install pre-commit

# Force reinstall hooks
pre-commit uninstall
pre-commit install
```

2. Hooks are slow:
```bash
# Use pre-commit's cache
pre-commit run --all-files  # First run caches results
```

3. Skip hooks temporarily:
```bash
git commit -m "message" --no-verify
```

### Hook-specific Issues

1. docker-compose-check:
- Ensure Docker is installed and running
- Verify docker-compose.yml syntax

2. shellcheck:
- Install shellcheck if missing: `apt-get install shellcheck`
- Check specific issues: `shellcheck script.sh`

3. hadolint:
- Install hadolint if missing
- Review ignored rules in .pre-commit-config.yaml

## Maintaining Hooks

To update hooks to their latest versions:
```bash
pre-commit autoupdate
```

To add new hooks, edit `.pre-commit-config.yaml` and run:
```bash
pre-commit install
```
