---
name: "create-homebrew-formula"
description: "Create and maintain Homebrew formulae for distributing tools on macOS"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "terminal_operations", "code_intelligence"]
---

# Create Homebrew Formula Skill

## When to Use

- Creating a Homebrew formula for a new tool
- Updating an existing formula to a new version
- Setting up automated formula updates
- Maintaining a Homebrew tap (repository)
- Troubleshooting formula installation issues

## Prerequisites

- Project has releases on GitHub (or other public source)
- Tool is installable via archive (tar.gz or zip)
- You know the tool's dependencies

## Quick Start

### 1. Gather Information

Before creating the formula, collect:
- **Project URL**: Where the tool lives (e.g., https://github.com/org/project)
- **Release version**: Current version tag (e.g., v1.2.3 or 20260201.1)
- **Download URL**: Direct link to release tarball (usually GitHub releases)
- **SHA256 hash**: Calculate from the tarball
- **Dependencies**: What the tool needs to run (e.g., perl, python, node)
- **License**: GPL-3.0, MIT, etc.

### 2. Calculate SHA256

```bash
curl -L -o /tmp/project-version.tar.gz "https://..."
shasum -a 256 /tmp/project-version.tar.gz
```

### 3. Create the Formula

Basic Homebrew formula template:

```ruby
class ProjectName < Formula
  desc "Human-readable description of what the tool does"
  homepage "https://github.com/org/project"
  url "https://github.com/org/project/releases/download/VERSION/project-VERSION.tar.gz"
  sha256 "SHA256_HASH_HERE"
  license "GPL-3.0"

  depends_on "perl"        # List dependencies
  # depends_on "python"
  # depends_on "git"

  def install
    # Copy files to libexec (standard Homebrew pattern)
    libexec.install Dir["*"]
    
    # Create executable symlink
    bin.install_symlink libexec/"project"
  end

  def post_install
    # Optional: Set up directories or files after installation
    # Example: Create config directory
    # config_dir = File.expand_path("~/.project")
    # Dir.mkdir(config_dir) unless File.directory?(config_dir)
  end

  test do
    # Verify the tool works after installation
    assert_match "version or help text", shell_output("#{bin}/project --help")
  end
end
```

### 4. Test Locally

```bash
# Test the formula
brew install -s ./Formula/project.rb

# Verify it works
project --version

# Run the built-in test
brew test project

# Clean up if needed
brew uninstall project
```

## Understanding Homebrew Naming

**Important:** Repository naming is critical for Homebrew taps:

- **Repository name**: Must start with `homebrew-`
  - Correct: `homebrew-sam`, `homebrew-tools`
  - Wrong: `sam`, `tools`

- **User installs with**: `brew tap organization/shortname`
  - Example: `brew tap SyntheticAutonomicMind/sam`
  - Homebrew automatically looks for `homebrew-sam`

- **File structure**: Standard layout
  ```
  homebrew-sam/
  ├── Formula/
  │   ├── clio.rb
  │   ├── sam.rb
  │   └── other-tool.rb
  ├── README.md
  ├── CONTRIBUTING.md
  └── .github/workflows/
  ```

## Advanced: Automation

### GitHub Actions Workflow

Automatically update formulas when new releases are published:

```yaml
name: Update Formula on Release

on:
  release:
    types: [published]

jobs:
  update:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - uses: actions/checkout@v4
        with:
          repository: organization/homebrew-repository
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Calculate SHA256
        id: hash
        run: |
          curl -L -o /tmp/tool.tar.gz "${{ github.event.release.assets[0].browser_download_url }}"
          SHA256=$(shasum -a 256 /tmp/tool.tar.gz | cut -d' ' -f1)
          echo "sha256=$SHA256" >> $GITHUB_OUTPUT

      - name: Update formula
        run: |
          VERSION="${{ github.ref }}"
          VERSION="${VERSION#refs/tags/}"
          URL="${{ github.event.release.assets[0].browser_download_url }}"
          SHA256="${{ steps.hash.outputs.sha256 }}"
          
          sed -i "s|url .*|url \"$URL\"|" Formula/project.rb
          sed -i "s|sha256 .*|sha256 \"$SHA256\"|" Formula/project.rb

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add Formula/project.rb
          git commit -m "chore(project): update to $VERSION"
          git push
```

### Helper Script

Manual formula updates can use a script:

```bash
#!/bin/bash
PROJECT=$1
VERSION=$2
URL=$3

# Download and hash
curl -L -o /tmp/${PROJECT}.tar.gz "$URL"
SHA256=$(shasum -a 256 /tmp/${PROJECT}.tar.gz | cut -d' ' -f1)

# Update formula
sed -i "s|url .*|url \"$URL\"|" Formula/${PROJECT}.rb
sed -i "s|sha256 .*|sha256 \"$SHA256\"|" Formula/${PROJECT}.rb

# Test
brew install -s ./Formula/${PROJECT}.rb
brew test ${PROJECT}
brew uninstall ${PROJECT}

echo "[OK] Updated Formula/${PROJECT}.rb"
```

## Common Issues & Solutions

### Formula Won't Install

**Check the formula syntax**:
```bash
brew audit --new-formula ./Formula/project.rb
```

**Verify dependencies exist**:
```bash
brew deps project
```

**Debug installation**:
```bash
brew install -s -v ./Formula/project.rb
```

### Test Block Fails

- Ensure the test command actually exists in your tool
- Use `--help` or `--version` flags if available
- Test what users can actually run

### SHA256 Mismatch

- Download the exact same file: `curl -L -o file.tar.gz URL`
- Calculate fresh: `shasum -a 256 file.tar.gz`
- Update formula with exact hash

### Dependency Issues

List available dependencies:
```bash
brew search perl
brew info perl
```

Add to formula:
```ruby
depends_on "perl"
depends_on "git"
```

## Best Practices

### 1. Keep Formulas Simple

```ruby
# GOOD: Straightforward installation
def install
  libexec.install Dir["*"]
  bin.install_symlink libexec/"tool"
end

# AVOID: Complex custom logic
def install
  # 50 lines of custom installation steps
end
```

### 2. Use Standard Patterns

```ruby
# Standard Homebrew patterns:
libexec.install Dir["*"]           # Copy everything to libexec
bin.install_symlink libexec/"name" # Create executable symlink
bin.install "script.sh" => "tool"  # Install and rename
```

### 3. Post-Install Setup

```ruby
def post_install
  # Create config directories
  config_dir = File.expand_path("~/.project")
  Dir.mkdir(config_dir) unless File.directory?(config_dir)
  
  # Create initial config if not present
  config_file = File.join(config_dir, "config.json")
  unless File.exist?(config_file)
    File.write(config_file, { version: version }.to_json)
  end
end
```

### 4. Test Block Coverage

```ruby
test do
  # Test basic functionality
  assert_match "version", shell_output("#{bin}/tool --version")
  
  # Test that help works
  assert_match "usage", shell_output("#{bin}/tool --help", 0)
  
  # Test actual functionality if quick
  output = shell_output("#{bin}/tool test-command")
  assert output.include?("expected result")
end
```

### 5. Documentation

Include in tap repository:

```markdown
# Project Homebrew Tap

## Installation

```bash
brew tap org/homebrew-project
brew install project
```

## Upgrading

```bash
brew upgrade project
```

## Uninstalling

```bash
brew uninstall project
brew untap org/homebrew-project
```

## Troubleshooting

- Issue: X → Solution: Y
```

## Real-World Example: CLIO

Full working example from SyntheticAutonomicMind:

**Repository**: `homebrew-sam` (contains multiple tools)

**Formula: Formula/clio.rb**
```ruby
class Clio < Formula
  desc "Command Line Intelligence Orchestrator - Terminal-native AI coding assistant"
  homepage "https://github.com/SyntheticAutonomicMind/CLIO"
  url "https://github.com/SyntheticAutonomicMind/CLIO/releases/download/20260201.1/clio-20260201.1.tar.gz"
  sha256 "8588e9b11157fb9f4e5683b2db723a4c5303f20c801583fd059c82af6a20b15e"
  license "GPL-3.0"

  depends_on "perl"

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"clio"
  end

  def post_install
    clio_dir = File.expand_path("~/.clio")
    Dir.mkdir(clio_dir) unless File.directory?(clio_dir)
  end

  test do
    assert_match "CLIO - Command Line Intelligent Operator", shell_output("#{bin}/clio --help")
    output = shell_output("echo '' | #{bin}/clio --debug --input 'test' --exit 2>&1", 0)
    assert_match "CLIO", output
  end
end
```

**Installation**:
```bash
brew tap SyntheticAutonomicMind/sam
brew install clio
clio --new
```

## References

- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [Homebrew Taps Documentation](https://docs.brew.sh/Taps)
- [Homebrew API](https://rubydoc.brew.sh/)

## Next Steps

Once your formula is working:

1. **Create a tap repository**: `homebrew-projectname`
2. **Test installation**: `brew tap org/projectname && brew install tool`
3. **Submit to homebrew-core** (optional, for official distribution)
4. **Set up automation** (GitHub Actions for auto-updates)
5. **Document in README**: Installation and troubleshooting

---

**Created for**: Distributing SAM tools (CLIO, SAM, etc.)  
**Maintained by**: SyntheticAutonomicMind  
**Last Updated**: 2026-02-01
