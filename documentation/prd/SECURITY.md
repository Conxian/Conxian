# Security & Monitoring

## Circuit Breaker
- `contracts/security/circuit-breaker.clar`
- Tracks per-operation success/failure rates, timeouts, rate limits, emergency shutdown.

## Pausable
- `contracts/security/Pausable.clar`
- Simple pause/unpause guards; test helpers provided.

## Monitoring
- `contracts/monitoring/system-monitor.clar`, `contracts/monitoring/monitoring-dashboard.clar`
- Event logging, thresholds, health status views.
