# 🐪 Perl Library Path Configuration Guide

## 📋 Overview

This document explains how to configure Perl library paths for the Mojo Poker application, ensuring portability across different environments.

## 🔧 Changes Made

**Removed hardcoded user-specific paths** from `script/mojopoker.pl`:

```perl
# BEFORE (non-portable):
use lib './lib', '/home/a520m/perl5/lib/perl5', '/home/a520m/perl5/lib/perl5/x86_64-linux-thread-multi';

# AFTER (portable):
use lib './lib';
```

## 🎯 Why This Change Was Made

1. **Portability**: User-specific paths (`/home/a520m/...`) prevent the script from running on other systems
2. **Maintainability**: Hardcoded paths require manual updates for each contributor
3. **Best Practices**: Follow Perl community standards for library path management

## 🚀 Recommended Configuration Methods

### Method 1: PERL5LIB Environment Variable (Recommended)

Set the `PERL5LIB` environment variable to include your Perl library paths:

```bash
# Temporary (current session only)
export PERL5LIB="/path/to/your/perl5/lib:$PERL5LIB"

# Permanent (add to your shell config: ~/.bashrc, ~/.zshrc, etc.)
echo 'export PERL5LIB="/path/to/your/perl5/lib:$PERL5LIB"' >> ~/.bashrc
source ~/.bashrc
```

### Method 2: local::lib (Advanced Users)

Use `local::lib` for user-local Perl module installations:

```bash
# Install local::lib
cpanm local::lib

# Add to your shell config
echo 'eval "$(perl -I$HOME/perl5/lib/perl5/ -Mlocal::lib)"' >> ~/.bashrc
source ~/.bashrc

# Install modules to your local library
cpanm --local-lib=~/perl5 Ships EV Mojo::Server::Daemon
```

### Method 3: Project-Specific Configuration

Create a `.env` file in the project root:

```bash
echo "PERL5LIB=./lib:/path/to/dependencies" > .env
```

Then load it before running:

```bash
source .env
perl script/mojopoker.pl
```

## 📋 Required Perl Modules

The application requires these Perl modules:

| Module | Purpose | Installation |
|--------|---------|--------------|
| `Ships` | Main application module | Included in `./lib` |
| `EV` | Event loop | `cpanm EV` |
| `Mojo::Server::Daemon` | Web server | `cpanm Mojolicious` |
| `POSIX` | System functions | Core Perl module |

## 🎨 Installation Instructions

### For Contributors

```bash
# Install required system dependencies
sudo apt-get install perl libperl-dev cpanminus

# Install Perl modules
cpanm EV Mojolicious

# Set up environment
export PERL5LIB="./lib:$PERL5LIB"

# Run the application
perl script/mojopoker.pl
```

### For Production Deployment

```bash
# Install system dependencies
sudo apt-get install perl libperl-dev cpanminus

# Create a dedicated user
sudo useradd -r -s /bin/false mojopoker
sudo su - mojopoker

# Install dependencies in user space
cpanm --local-lib=~/perl5 EV Mojolicious

# Configure environment
echo 'export PERL5LIB="./lib:$HOME/perl5/lib/perl5:$PERL5LIB"' >> ~/.bashrc
source ~/.bashrc

# Run the application
perl script/mojopoker.pl
```

## 🔍 Troubleshooting

### Common Issues

**Issue**: `Can't locate Ships.pm in @INC`
**Solution**: Ensure `./lib` is in your `PERL5LIB` and you're running from the project root

**Issue**: `Can't locate EV.pm in @INC`
**Solution**: Install EV module: `cpanm EV`

**Issue**: `Can't locate Mojo/Server/Daemon.pm in @INC`
**Solution**: Install Mojolicious: `cpanm Mojolicious`

### Debugging Library Paths

```bash
# Check current @INC paths
perl -e 'print join("\n", @INC)'

# Check PERL5LIB
echo $PERL5LIB

# Test module loading
perl -e 'use Ships; print "Ships loaded successfully\n"'
```

## 📁 Project Structure

```
mojopoker-1.1.1/
├── lib/                  # Project-specific Perl modules
│   ├── Ships.pm          # Main application module
│   └── ...               # Other project modules
├── script/
│   └── mojopoker.pl      # Main application script (uses portable lib paths)
└── ...
```

## 🔄 Migration Guide

If you previously had hardcoded paths in your environment:

1. **Remove old paths** from your scripts
2. **Update your environment** to use `PERL5LIB` or `local::lib`
3. **Test thoroughly** in your environment

## 🎯 Best Practices

1. **Never commit user-specific paths** to version control
2. **Use relative paths** for project-local dependencies (`./lib`)
3. **Document external dependencies** clearly
4. **Provide setup instructions** for contributors
5. **Test in clean environments** to ensure portability

## 📖 Additional Resources

- [Perl PERL5LIB Documentation](https://perldoc.pl/perlrun#PERL5LIB)
- [local::lib Documentation](https://metacpan.org/pod/local::lib)
- [cpanm Documentation](https://metacpan.org/pod/App::cpanminus)

## 🤝 Contributing

When contributing to this project:

1. **Use portable paths** in all scripts
2. **Document new dependencies** in this file
3. **Test in multiple environments** before submitting changes
4. **Update installation instructions** if you add new requirements

By following these guidelines, we ensure the Mojo Poker application remains portable and easy to set up across different development and production environments.