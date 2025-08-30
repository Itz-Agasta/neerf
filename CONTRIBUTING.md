# Contributing to NERRF

Thank you for your interest in contributing to the Neural Execution Reversal & Recovery Framework (NERRF)! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Reporting Issues](#reporting-issues)
- [Style Guidelines](#style-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)
- [License](#license)

## Code of Conduct

This project adheres to the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/your-username/nerrf.git
   cd nerrf
   ```
3. **Set up the development environment** (see below)
4. **Create a feature branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- **Kubernetes cluster** (Minikube, Kind, or cloud-based)
- **Helm 3.x**
- **Python 3.8+** with pip
- **Go 1.19+** (for eBPF components)
- **Docker** (for containerized builds)
- **Make** (for build automation)

### Installation

1. **Install dependencies**:

   ```bash
   # Python dependencies
   pip install -r requirements.txt

   # Go dependencies
   go mod download

   # Helm charts
   helm dependency update
   ```

2. **Build the project**:

   ```bash
   make all
   ```

3. **Run tests**:
   ```bash
   make test
   ```

### Development Workflow

- Use `make dev` for development builds with hot reload
- Use `make demo` to spin up a local test environment
- Use `make clean` to reset the workspace

## How to Contribute

### Types of Contributions

- **Bug fixes**: Fix issues in the issue tracker
- **Features**: Implement new functionality
- **Documentation**: Improve docs, tutorials, or examples
- **Tests**: Add or improve test coverage
- **Research**: Contribute to AI models, algorithms, or benchmarks

### Contribution Process

1. **Check existing issues** and pull requests to avoid duplication
2. **Create an issue** for significant changes before starting work
3. **Follow the development setup** above
4. **Write tests** for new functionality
5. **Update documentation** as needed
6. **Submit a pull request** with a clear description

## Pull Request Process

1. **Ensure your PR meets the following criteria**:

   - All tests pass (`make test`)
   - Code follows the style guidelines
   - Documentation is updated
   - No breaking changes without discussion

2. **PR Description**:

   - Clearly describe the changes
   - Reference any related issues
   - Include screenshots for UI changes
   - List any breaking changes

3. **Review Process**:
   - Maintainers will review your PR
   - Address any feedback or requested changes
   - Once approved, a maintainer will merge your PR

## Reporting Issues

- Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) for bugs
- Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) for new features
- Provide as much detail as possible:
  - Steps to reproduce
  - Expected vs. actual behavior
  - Environment details
  - Screenshots or logs

## Style Guidelines

### Code Style

- **Python**: Follow PEP 8 with Black formatter
- **Go**: Use `gofmt` and follow standard Go conventions
- **YAML**: Use 2-space indentation, consistent formatting
- **Markdown**: Follow the style used in existing documentation

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (e.g., "Add", "Fix", "Update")
- Reference issue numbers when applicable
- Example: `Fix dependency tracking in eBPF probe (#123)`

### Branch Naming

- Use descriptive names: `feature/add-gnn-model`, `fix/rollback-bug`, `docs/update-readme`

## Testing

- **Unit tests**: Test individual components
- **Integration tests**: Test component interactions
- **Benchmark tests**: Validate performance metrics
- **Security tests**: Ensure no vulnerabilities introduced

Run the full test suite:

```bash
make test
```

## Documentation

- **Code documentation**: Use docstrings/comments for all public APIs
- **User documentation**: Update README.md and docs/ for user-facing changes
- **API documentation**: Auto-generated from code comments
- **Examples**: Provide runnable examples for new features

## License

By contributing to NERRF, you agree that your contributions will be licensed under the same license as the project (AGPL v3). See [LICENSE](LICENSE) for details.

## Recognition

Contributors are recognized in the following ways:

- Listed in CONTRIBUTORS.md (if applicable)
- Mentioned in release notes
- Acknowledged in commit messages

Thank you for contributing to NERRF! 🚀
