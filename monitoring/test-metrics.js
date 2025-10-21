const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

class TestMetricsCollector {
  constructor() {
    this.metricsDir = path.join(__dirname, '.metrics');
    this.metricsFile = path.join(this.metricsDir, 'test-metrics.json');
    this.ensureMetricsDir();
    this.metrics = this.loadMetrics();
  }

  ensureMetricsDir() {
    if (!fs.existsSync(this.metricsDir)) {
      fs.mkdirSync(this.metricsDir, { recursive: true });
    }
  }

  loadMetrics() {
    try {
      if (fs.existsSync(this.metricsFile)) {
        return JSON.parse(fs.readFileSync(this.metricsFile, 'utf8'));
      }
    } catch (error) {
      console.error('Error loading metrics:', error);
    }
    return [];
  }

  saveMetrics() {
    try {
      fs.writeFileSync(this.metricsFile, JSON.stringify(this.metrics, null, 2));
    } catch (error) {
      console.error('Error saving metrics:', error);
    }
  }

  collectTestResults() {
    try {
      // Run tests and capture output
      const output = execSync('npm test -- --json', { encoding: 'utf8' });
      const results = JSON.parse(output);
      
      // Extract metrics
      const metrics = {
        timestamp: new Date().toISOString(),
        totalTests: results.numTotalTests,
        passedTests: results.numPassedTests,
        failedTests: results.numFailedTests,
        coverage: this.getCoverage(),
        performance: this.getPerformanceMetrics(),
        flakyTests: this.detectFlakyTests()
      };

      // Add to history
      this.metrics.push(metrics);
      
      // Keep only last 100 runs
      if (this.metrics.length > 100) {
        this.metrics = this.metrics.slice(-100);
      }
      
      this.saveMetrics();
      return metrics;
    } catch (error) {
      console.error('Error collecting test results:', error);
      return null;
    }
  }

  getCoverage() {
    try {
      const coveragePath = path.join(process.cwd(), 'coverage', 'coverage-summary.json');
      if (fs.existsSync(coveragePath)) {
        const coverage = JSON.parse(fs.readFileSync(coveragePath, 'utf8'));
        return {
          statements: coverage.total.statements.pct,
          branches: coverage.total.branches.pct,
          functions: coverage.total.functions.pct,
          lines: coverage.total.lines.pct
        };
      }
    } catch (error) {
      console.error('Error getting coverage:', error);
    }
    return null;
  }

  getPerformanceMetrics() {
    // This would be populated with actual performance metrics
    // from your performance tests
    return {
      avgResponseTime: 0,
      p95ResponseTime: 0,
      requestsPerSecond: 0
    };
  }

  detectFlakyTests() {
    // This would analyze test history to detect flaky tests
    // For now, return an empty array
    return [];
  }

  generateReport() {
    if (this.metrics.length === 0) {
      return 'No test metrics available. Run tests first.';
    }

    const latest = this.metrics[this.metrics.length - 1];
    const prev = this.metrics.length > 1 ? this.metrics[this.metrics.length - 2] : null;

    let report = `Test Metrics Report (${new Date().toISOString()})
=================================
`;
    report += `Total Tests: ${latest.totalTests}
`;
    report += `Passed: ${latest.passedTests} (${((latest.passedTests / latest.totalTests) * 100).toFixed(1)}%)\n`;
    report += `Failed: ${latest.failedTests} (${((latest.failedTests / latest.totalTests) * 100).toFixed(1)}%)\n\n`;

    if (latest.coverage) {
      report += 'Coverage:\n';
      Object.entries(latest.coverage).forEach(([key, value]) => {
        report += `  ${key}: ${value}%\n`;
      });
      report += '\n';
    }

    if (prev) {
      const testDiff = latest.totalTests - prev.totalTests;
      const passDiff = latest.passedTests - prev.passedTests;
      
      report += 'Changes from previous run:\n';
      report += `  Total tests: ${testDiff >= 0 ? '+' : ''}${testDiff}\n`;
      report += `  Passed tests: ${passDiff >= 0 ? '+' : ''}${passDiff}\n`;
    }

    return report;
  }
}

// Export a singleton instance
module.exports = new TestMetricsCollector();
