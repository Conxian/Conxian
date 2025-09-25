# Conxian CI/CD Pipeline Documentation

## Overview

This document describes the enhanced CI/CD pipeline for the Conxian protocol, providing automated testing, building, and deployment capabilities.

## Pipeline Structure

The pipeline consists of several key stages:

1. **Validation**: Initial checks and setup
2. **Security**: Security scanning and code quality checks
3. **Test**: Unit and integration testing
4. **Build**: Docker image creation and packaging
5. **Deploy**: Automated deployment to environments
6. **Post-Deploy**: Verification and reporting

## Workflow Triggers

- **Push to main/develop**: Runs tests and builds
- **Pull Requests**: Runs tests and security checks
- **Manual Dispatch**: Trigger deployments to different environments
- **Scheduled**: Weekly security scans

## Environment Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NODE_VERSION` | Node.js version | No | 20 |
| `CLARINET_VERSION` | Clarinet version | No | 3.5.0 |
| `DOCKERHUB_USERNAME` | Docker Hub username | Yes | - |
| `IMAGE_NAME` | Docker image name | No | conxian-protocol |

## Required Secrets

| Secret | Description |
|--------|-------------|
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `AWS_ACCESS_KEY_ID` | AWS access key for deployments |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for deployments |
| `SLACK_WEBHOOK_URL` | Webhook URL for notifications |
| `CODECOV_TOKEN` | Codecov access token |

## Manual Deployment

Deploy to an environment using the GitHub Actions UI:

1. Go to Actions > Enhanced CI/CD Pipeline
2. Click "Run workflow"
3. Select the environment (staging/production)
4. Click "Run workflow"

## Monitoring and Alerts

- **Success/Failure Notifications**: Sent to configured Slack channel
- **Deployment Status**: Available in GitHub Actions UI
- **Test Coverage**: Reported to Codecov
- **Security Alerts**: Generated for vulnerabilities

## Rollback Procedure

To rollback a deployment:

1. Identify the previous working commit
2. Revert to the previous version:
   ```bash
   git revert <commit-hash>
   git push origin main
   ```
3. The CI/CD pipeline will automatically deploy the previous version

## Troubleshooting

### Common Issues

1. **Build Failures**:
   - Check test logs for failures
   - Verify dependency versions
   - Ensure all required environment variables are set

2. **Deployment Issues**:
   - Check AWS credentials
   - Verify network connectivity
   - Review deployment logs

3. **Test Failures**:
   - Run tests locally
   - Check for environment-specific issues
   - Review test coverage reports

## Best Practices

1. **Branch Protection**:
   - Require status checks to pass before merging
   - Enforce code review requirements
   - Prevent force pushes

2. **Security**:
   - Regularly update dependencies
   - Scan for vulnerabilities
   - Use secret management

3. **Monitoring**:
   - Monitor deployment health
   - Set up alerts for failures
   - Regularly review logs

## Support

For issues with the CI/CD pipeline, contact the DevOps team or create an issue in the repository.
