# Version Management Proposals

## Option 1: JSON Manifest (`versions.json`)
### Advantages:
- Structured format with nested configuration support
- Excellent Dependabot support via custom updaters
- Single file for all versions
- Easy to parse in scripts
- Good for complex version constraints

### Disadvantages:
- Requires JSON parsing in shell scripts
- More complex than simple env files

## Option 2: Individual Version Files (`versions/*.txt`)
### Advantages:
- Simple, one version per file
- Direct Dependabot scanning
- Easy to update individual components
- Clean git history per component
- Simple to read in shell scripts

### Disadvantages:
- Many files to manage
- Directory structure overhead
- No nested configuration support

## Option 3: ENV File (`.env`)
### Advantages:
- Simple key-value format
- Easy to source in shell scripts
- Familiar format for developers
- Works with docker-compose out of the box

### Disadvantages:
- Limited Dependabot support
- No structured data support
- Can become messy with many variables

## Recommendation
For the rover project, I recommend Option 1 (JSON Manifest) because:
1. It provides structured version management
2. Excellent Dependabot integration
3. Single file to maintain
4. Can be easily parsed in any language
5. Supports complex version constraints if needed
6. Clean git history for version updates

### Example Dependabot Configuration
```yaml
version: 2
updates:
  - package-ecosystem: "custom"
    directory: "/"
    schedule:
      interval: "weekly"
    target-branch: "main"
    custom-configuration:
      - file: "versions.json"
        type: "json"
        update-types:
          - "version-update:semver-patch"
          - "version-update:semver-minor"
```

This configuration would allow Dependabot to automatically update versions while maintaining semantic versioning rules.
