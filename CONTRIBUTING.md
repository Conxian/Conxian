# Contributing to Conxian

Thank you for your interest in contributing to the Conxian project! This document provides guidelines and workflows to ensure consistent and high-quality contributions.

## Development Workflow

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch for features
- `feature/*` - Feature development branches
- `fix/*` - Bug fix branches
- `release/*` - Release preparation branches

### Commit Guidelines

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <subject>
```

#### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Formatting changes
- `refactor`: Code refactoring
- `test`: Test additions or modifications
- `chore`: Maintenance tasks
- `perf`: Performance improvements
- `security`: Security fixes

#### Scopes
- `contracts`: Smart contracts
- `dex`: Decentralized exchange components
- `oracle`: Oracle system
- `math`: Mathematical libraries
- `traits`: Trait definitions
- `utils`: Utility functions
- `vaults`: Vault implementations
- `tests`: Test files
- `docs`: Documentation
- `ci`: Continuous integration
- `deps`: Dependencies
- `all`: Multiple scopes

### Pull Request Process

1. Create a feature or fix branch from `develop`
2. Implement your changes with appropriate tests
3. Ensure all tests pass with `clarinet test`
4. Submit a pull request to the `develop` branch
5. Address any review comments

## Code Standards

### Clarity Code Style

- Use 2-space indentation
- Keep functions focused and small
- Document public functions with comments
- Follow trait interfaces precisely
- Use meaningful variable names

### Testing Requirements

- All new features must include unit tests
- Integration tests for complex interactions
- Test edge cases and error conditions
- Maintain test coverage above 80%

## Documentation

- Update documentation for all new features
- Include inline comments for complex logic
- Provide examples for public interfaces
- Keep the README and other docs up to date

## Security Considerations

- Never commit secrets or private keys
- Follow security best practices
- Report security issues privately
- Consider economic attack vectors

## Getting Help

If you need assistance, please:
- Check existing documentation
- Review open and closed issues
- Join the community chat
- Reach out to maintainers

Thank you for contributing to Conxian!