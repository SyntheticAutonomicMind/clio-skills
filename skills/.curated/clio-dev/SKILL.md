---
name: "clio-dev"
description: "Development guidelines for contributing to the CLIO project"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations", "terminal_operations", "version_control"]
note: "This skill is specifically for working on the CLIO codebase"
---

# CLIO Development Skill

> **Note:** This skill provides guidelines specific to the CLIO project. 
> It should only be used when working on CLIO's own codebase.

## When to Use

- Working on CLIO's core codebase
- Adding new features to CLIO
- Fixing bugs in CLIO
- Extending CLIO's tool system

## CLIO Architecture Overview

```
clio                           # Main executable
lib/CLIO/
├── Core/                      # System core
│   ├── APIManager.pm          # AI provider integration
│   ├── Config.pm              # Configuration management
│   ├── ToolExecutor.pm        # Tool invocation routing
│   └── WorkflowOrchestrator.pm # AI tool orchestration
├── Tools/                     # AI-callable tools
│   ├── FileOperations.pm      # File system operations
│   ├── VersionControl.pm      # Git operations
│   └── TerminalOperations.pm  # Shell command execution
├── UI/                        # Terminal interface
│   ├── Chat.pm                # Main chat interface
│   ├── Display.pm             # Message formatting
│   ├── Theme.pm               # Theming/styling
│   ├── Markdown.pm            # Markdown rendering
│   └── Commands/              # Slash command handlers
├── Session/                   # Session management
│   ├── Manager.pm
│   └── State.pm
└── Memory/                    # Context/memory system
    ├── ShortTerm.pm
    └── LongTerm.pm
```

## Development Standards

### Module Requirements

Every CLIO module must have:

```perl
package CLIO::Module::Name;

use strict;
use warnings;
use utf8;
binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# POD documentation
=head1 NAME
CLIO::Module::Name - Brief description

=head1 DESCRIPTION
Detailed description

=cut

# Implementation...

1;  # REQUIRED: All .pm files must end with 1;
```

### Debug Logging

```perl
use CLIO::Core::Logger qw(should_log log_debug);

# Always guard debug output
if (should_log('DEBUG')) {
    print STDERR "[DEBUG][ModuleName] message\n";
}
# Or use:
log_debug('ModuleName', 'message');
```

### Error Handling

```perl
# CORRECT: Use error handlers
eval {
    dangerous_operation();
};
if ($@) {
    $self->display_error_message("Operation failed: $@");
    return { success => 0, error => $@ };
}

# WRONG: Never bare die in tool execution
die "Error message";  # This crashes the AI loop!
```

### Syntax Check Before Commit

```bash
# MANDATORY before any commit
perl -I./lib -c lib/CLIO/Path/To/Module.pm

# Check all at once
find lib -name "*.pm" -exec perl -I./lib -c {} \;
```

## Adding New Tools

1. Create tool in `lib/CLIO/Tools/YourTool.pm`:

```perl
package CLIO::Tools::YourTool;
use parent 'CLIO::Tools::Tool';

sub new {
    my ($class, %opts) = @_;
    return $class->SUPER::new(
        name => 'your_tool',
        description => 'What this tool does',
        %opts
    );
}

sub execute {
    my ($self, $params, $context) = @_;
    # Implement tool operation
    return { success => 1, result => $data };
}

1;
```

2. Register in `lib/CLIO/Tools/Registry.pm`
3. Add POD documentation
4. Create tests in `tests/unit/`
5. Update tool definition in system prompt

## Adding Slash Commands

Commands live in `lib/CLIO/UI/Commands/`. Follow existing patterns:

1. Create `lib/CLIO/UI/Commands/YourCommand.pm`
2. Delegate display methods to chat
3. Use unified display helpers:
   - `display_command_header()`
   - `display_section_header()`
   - `display_command_row()`
   - `display_key_value()`
4. Register in `CommandHandler.pm`

## Commit Message Format

```
type(scope): brief description

Problem: What was broken/incomplete
Solution: How you fixed it
Testing: How you verified the fix
```

Types: feat, fix, refactor, docs, test, chore

## Testing

```bash
# Syntax check all modified files
perl -I./lib -c lib/CLIO/Core/MyModule.pm

# Run unit tests
perl -I./lib tests/unit/test_mymodule.pl

# Manual integration test
./clio --debug --input "test your change" --exit
```

## Anti-Patterns (NEVER DO)

- Skip syntax check before commit
- `print()` without `should_log()` check
- `TODO`/`FIXME` comments in final code
- Bare `die` in tool execution
- Modules without `1;` at the end
- Unguarded debug output
- Adding UI clutter (tool execution announcements)
