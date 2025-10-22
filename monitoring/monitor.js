#!/usr/bin/env node

const metrics = require('./test-metrics');
const fs = require('fs');
const path = require('path');
const { program } = require('commander');

program
  .command('run')
  .description('Run tests and collect metrics')
  .action(() => {
    console.log('Running tests and collecting metrics...');
    const results = metrics.collectTestResults();
    if (results) {
      console.log('\nTest execution completed.');
      console.log(metrics.generateReport());
      
      // Generate HTML report
      generateHtmlReport(metrics.metrics);
    } else {
      console.error('Failed to collect test metrics');
      process.exit(1);
    }
  });

program
  .command('report')
  .description('Generate a test metrics report')
  .action(() => {
    console.log(metrics.generateReport());
    generateHtmlReport(metrics.metrics);
  });

program.parse(process.argv);

function generateHtmlReport(metricsData) {
  if (metricsData.length === 0) {
    console.log('No metrics data available to generate report');
    return;
  }

  const latest = metricsData[metricsData.length - 1];
  const reportDir = path.join(__dirname, 'reports');
  
  if (!fs.existsSync(reportDir)) {
    fs.mkdirSync(reportDir, { recursive: true });
  }

  const html = `
  <!DOCTYPE html>
  <html>
  <head>
    <title>Test Metrics Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
      body { font-family: Arial, sans-serif; margin: 20px; }
      .metrics-container { display: flex; flex-wrap: wrap; gap: 20px; }
      .metric-card { 
        background: #f5f5f5; 
        border-radius: 8px; 
        padding: 15px; 
        flex: 1; 
        min-width: 200px;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .chart-container { margin-top: 30px; }
      h1 { color: #333; }
      .summary { 
        background: #e9f7ef; 
        padding: 15px; 
        border-radius: 8px; 
        margin-bottom: 20px;
      }
      .failed { color: #d32f2f; font-weight: bold; }
      .passed { color: #388e3c; font-weight: bold; }
    </style>
  </head>
  <body>
    <h1>Test Metrics Report</h1>
    <p>Generated: ${new Date().toLocaleString()}</p>
    
    <div class="summary">
      <h2>Summary</h2>
      <p>Total Tests: ${latest.totalTests}</p>
      <p class="passed">Passed: ${latest.passedTests} (${((latest.passedTests / latest.totalTests) * 100).toFixed(1)}%)</p>
      <p class="failed">Failed: ${latest.failedTests} (${((latest.failedTests / latest.totalTests) * 100).toFixed(1)}%)</p>
    </div>
    
    <div class="metrics-container">
      ${latest.coverage ? `
      <div class="metric-card">
        <h3>Code Coverage</h3>
        <p>Statements: ${latest.coverage.statements}%</p>
        <p>Branches: ${latest.coverage.branches}%</p>
        <p>Functions: ${latest.coverage.functions}%</p>
        <p>Lines: ${latest.coverage.lines}%</p>
      </div>` : ''}
      
      <div class="metric-card">
        <h3>Performance</h3>
        <p>Avg. Response: ${latest.performance?.avgResponseTime || 'N/A'} ms</p>
        <p>P95: ${latest.performance?.p95ResponseTime || 'N/A'} ms</p>
        <p>Throughput: ${latest.performance?.requestsPerSecond || 'N/A'} req/s</p>
      </div>
    </div>
    
    <div class="chart-container">
      <canvas id="testTrends"></canvas>
    </div>
    
    <script>
      // Test trends chart
      const ctx = document.getElementById('testTrends').getContext('2d');
      const metricsData = ${JSON.stringify(metricsData)};
      
      new Chart(ctx, {
        type: 'line',
        data: {
          labels: metricsData.map((_, i) => `Run ${i + 1}`),
          datasets: [
            {
              label: 'Total Tests',
              data: metricsData.map(m => m.totalTests),
              borderColor: 'rgb(75, 192, 192)',
              tension: 0.1
            },
            {
              label: 'Passed Tests',
              data: metricsData.map(m => m.passedTests),
              borderColor: 'rgb(56, 142, 60)',
              tension: 0.1
            },
            {
              label: 'Failed Tests',
              data: metricsData.map(m => m.failedTests),
              borderColor: 'rgb(211, 47, 47)',
              tension: 0.1
            }
          ]
        },
        options: {
          responsive: true,
          scales: {
            y: {
              beginAtZero: true
            }
          }
        }
      });
    </script>
  </body>
  </html>
  `;

  const reportPath = path.join(reportDir, `test-report-${new Date().toISOString().replace(/[:.]/g, '-')}.html`);
  fs.writeFileSync(reportPath, html);
  console.log(`\nHTML report generated: file://${reportPath}`);
}
