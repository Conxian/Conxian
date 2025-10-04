# Contributing to StacksOrbit

Thank you for your interest in contributing to StacksOrbit! 🚀

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/Anya-org/stacksorbit/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - System information (OS, Python version)
   - Screenshots if applicable

### Suggesting Features

1. Check [Discussions](https://github.com/Anya-org/stacksorbit/discussions) for existing suggestions
2. Create a new discussion with:
   - Clear use case
   - Proposed solution
   - Potential impact

### Pull Requests

1. **Fork** the repository
2. **Create a branch** from `develop`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
3. **Make your changes**
4. **Test thoroughly**
5. **Commit** with clear messages:
   ```bash
   git commit -m "feat: add awesome feature"
   ```
6. **Push** to your fork
7. **Open a Pull Request** to `develop` branch

## Development Setup

### Prerequisites

- Python 3.8+
- Node.js 14+
- Git

### Installation

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/stacksorbit.git
cd stacksorbit

# Install Python dependencies
pip install -e ".[dev,test]"

# Install Node dependencies
npm install

# Run tests
npm test
```

## Code Style

### Python

- Follow [PEP 8](https://pep8.org/)
- Use [Black](https://black.readthedocs.io/) for formatting
- Maximum line length: 100 characters

```bash
# Format code
black stacksorbit.py

# Lint
pylint stacksorbit.py

# Type check
mypy stacksorbit.py
```

### JavaScript

- Follow [StandardJS](https://standardjs.com/)
- Use ES6+ features

```bash
# Lint
npm run lint
```

## Testing

### Run All Tests

```bash
npm test
```

### Run Specific Tests

```bash
# Python unit tests
pytest tests/unit/

# Python integration tests  
pytest tests/integration/

# GUI tests
python tests/test_gui.py
```

### Test Coverage

```bash
pytest --cov=stacksorbit --cov-report=html
```

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance

Examples:
```
feat: add multi-network parallel deployment
fix: resolve stop button state issue
docs: update installation instructions
```

## Pull Request Process

1. **Update documentation** if needed
2. **Add tests** for new features
3. **Ensure all tests pass**
4. **Update CHANGELOG.md**
5. **Request review** from maintainers

### PR Checklist

- [ ] Tests pass locally
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] No merge conflicts

## Release Process

1. Version bump in `package.json` and `setup.py`
2. Update `CHANGELOG.md`
3. Create git tag: `v1.x.x`
4. Push tag: `git push origin v1.x.x`
5. GitHub Actions handles publishing

## Questions?

- 💬 [GitHub Discussions](https://github.com/Anya-org/stacksorbit/discussions)
- 📧 Email: dev@anyachainlabs.com

Thank you for contributing! 🎉
