---
name: "perl-best-practices"
description: "Modern Perl 5 coding standards and best practices"
version: "1.0.0"
author: "CLIO Team"
tools: ["file_operations"]
---

# Perl Best Practices Skill

## When to Use

- Writing new Perl code
- Reviewing Perl code
- Refactoring legacy Perl
- Learning modern Perl patterns

## Modern Perl Standards

### Always Start With

```perl
use strict;
use warnings;
use utf8;

# For scripts that output text
binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');
```

### Package Structure

```perl
package My::Module;

use strict;
use warnings;
use utf8;

# Imports with explicit symbols
use Carp qw(croak confess);
use File::Spec;
use JSON::PP qw(encode_json decode_json);

# Version
our $VERSION = '1.0.0';

=head1 NAME

My::Module - Brief description

=head1 SYNOPSIS

    use My::Module;
    my $obj = My::Module->new(option => 'value');

=head1 DESCRIPTION

Detailed description.

=cut

# Constructor
sub new {
    my ($class, %args) = @_;
    
    my $self = {
        option => $args{option} // 'default',
    };
    
    return bless $self, $class;
}

# Methods...

1;  # Don't forget this!

__END__

=head1 AUTHOR

Your Name

=cut
```

### Error Handling

```perl
# Good: Use croak for caller errors
sub process {
    my ($self, $input) = @_;
    croak "Input required" unless defined $input;
    ...
}

# Good: Use eval for recoverable errors
my $result = eval {
    dangerous_operation();
};
if ($@) {
    warn "Operation failed: $@";
    return undef;
}

# Bad: bare die in library code
die "Error";  # Unhelpful stack trace
```

### Naming Conventions

```perl
# Package names: CamelCase
package My::ModuleName;

# Subroutines: snake_case
sub process_data { ... }

# Private subs: leading underscore
sub _internal_helper { ... }

# Constants: UPPERCASE
use constant MAX_RETRIES => 3;

# Variables: snake_case
my $user_input = '';
my @file_list = ();
my %config_options = ();
```

### Modern Features (Perl 5.10+)

```perl
# Say (implicit newline)
say "Hello, World!";  # Instead of: print "...\n"

# Defined-or operator
my $value = $input // 'default';  # Instead of: defined $input ? $input : 'default'

# State variables (persistent across calls)
sub counter {
    state $count = 0;
    return ++$count;
}

# Given-when (use with care, consider if-elsif instead)
use feature 'switch';
```

### Object-Oriented Perl

```perl
# Modern OO with accessors
package My::Class;

sub new {
    my ($class, %args) = @_;
    my $self = bless {}, $class;
    $self->name($args{name}) if exists $args{name};
    return $self;
}

# Accessor pattern
sub name {
    my ($self, $value) = @_;
    if (@_ > 1) {
        $self->{name} = $value;
        return $self;  # Allow chaining
    }
    return $self->{name};
}
```

### File Handling

```perl
# Good: Three-argument open with lexical filehandle
open my $fh, '<:encoding(UTF-8)', $filename
    or croak "Cannot open $filename: $!";
my $content = do { local $/; <$fh> };  # Slurp
close $fh;

# Better: autodie pragma
use autodie;
open my $fh, '<:encoding(UTF-8)', $filename;
# No need for "or die" - autodie handles it

# Writing
open my $fh, '>:encoding(UTF-8)', $filename;
print $fh $content;
close $fh;
```

### Regular Expressions

```perl
# Use named captures (5.10+)
if ($text =~ /^(?<prefix>\w+):(?<value>.*)$/) {
    my $prefix = $+{prefix};
    my $value = $+{value};
}

# Use /x for readability
my $regex = qr{
    ^\s*             # Leading whitespace
    (\w+)            # Capture word
    \s*:\s*          # Colon with optional spaces
    (.*)             # Rest of line
    $
}x;

# Use qr// for compiled regexes
my $pattern = qr/\d{4}-\d{2}-\d{2}/;
```

### Common Pitfalls

```perl
# WRONG: Forgetting to return in subs
sub get_value {
    my $result = calculate();
    # Missing: return $result;
}

# WRONG: Modifying $_ unexpectedly
for (@array) {
    chomp;  # This modifies @array!
}

# CORRECT: Use explicit variable
for my $item (@array) {
    my $clean = $item;
    chomp $clean;
}

# WRONG: Hash in boolean context
if (%hash) { ... }  # Works but not obvious intent

# CORRECT: Explicit check
if (keys %hash) { ... }
```

### Testing

```perl
use Test::More;

# Basic tests
is($got, $expected, 'description');
ok($condition, 'description');
like($string, qr/pattern/, 'description');

# Deep comparison
is_deeply(\@got, \@expected, 'arrays match');
is_deeply(\%got, \%expected, 'hashes match');

# Exception testing
eval { dangerous_call() };
like($@, qr/expected error/, 'dies correctly');

done_testing();
```
