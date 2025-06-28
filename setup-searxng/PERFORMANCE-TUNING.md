# SearXNG Performance Tuning Guide

> **🚀 Performance Optimization**: Solutions for "Too Many Requests" and Scaling Issues  
> **Target**: Multi-tenant OpenWebUI deployments with concurrent search requests

## Table of Contents
- [Overview](#overview)
- [Understanding "Too Many Requests"](#understanding-too-many-requests)
- [Immediate Solutions (High Priority)](#immediate-solutions-high-priority)
- [Scaling Solutions (Medium Priority)](#scaling-solutions-medium-priority)
- [Advanced Optimizations (Low Priority)](#advanced-optimizations-low-priority)

## Overview

This guide addresses performance issues with SearXNG in multi-tenant environments, specifically the "too many requests" error that occurs when multiple OpenWebUI instances make concurrent search requests.

### Common Symptoms
- ❌ "Too many requests" errors in OpenWebUI
- ❌ Search timeouts or slow responses
- ❌ Intermittent search failures
- ❌ High CPU/memory usage on SearXNG pods

### Root Causes
1. **Rate Limiter**: SearXNG's built-in rate limiting blocks concurrent requests
2. **Resource Constraints**: Insufficient CPU/memory for concurrent processing
3. **Single Pod Bottleneck**: Only one SearXNG pod handling all requests
4. **Search Engine Overload**: Too many search engines queried simultaneously

## Understanding "Too Many Requests"

### Rate Limiting Behavior
SearXNG implements rate limiting to prevent abuse, which can be triggered by:
- Multiple requests from the same source IP
- High request frequency from OpenWebUI instances
- Resource exhaustion causing slow responses

### Multi-Tenant Impact
In a multi-tenant setup:
- All requests appear to come from the same Kubernetes cluster IP
- Multiple OpenWebUI instances create concurrent request bursts
- Rate limiter treats all tenants as a single user

## Immediate Solutions (High Priority)

### 1. Disable Rate Limiter ✅ **IMPLEMENTED**

**Status**: ✅ Already configured in `searxng-values.yaml`

The rate limiter has been disabled for internal use:
```yaml
searxng:
  config:
    server:
      limiter: false  # Disabled for internal multi-tenant use
```

**Why this works**: Eliminates the primary cause of "too many requests" errors in trusted internal environments.

### 2. Increase Resource Limits

**Current Configuration**:
```yaml
resources:
  requests:
    cpu: "200m"
    memory: "512Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
```

**Recommended Configuration**:
```yaml
resources:
  requests:
    cpu: "500m"      # 2.5x increase
    memory: "1Gi"    # 2x increase
  limits:
    cpu: "2000m"     # 2x increase
    memory: "2Gi"    # 2x increase
```

**Implementation**:
```bash
# Update searxng-values.yaml with new resource limits
# Then upgrade the deployment
helm upgrade searxng searxng/searxng -f searxng-values.yaml -n vllm-inference
```

### 3. Set Minimum Replica Count

**Current Configuration**:
```yaml
# Single pod (default)
replicaCount: 1
```

**Recommended Configuration**:
```yaml
# Multiple pods for load distribution
replicaCount: 3

# Ensure high availability
podDisruptionBudget:
  enabled: true
  minAvailable: 2
```

**Benefits**:
- Distributes load across multiple pods
- Provides redundancy and fault tolerance
- Reduces per-pod request pressure

## Scaling Solutions (Medium Priority)

### 1. Enable Horizontal Pod Autoscaler (HPA)

**Configuration**:
```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

**Implementation**:
```bash
# Enable HPA in searxng-values.yaml
# Upgrade deployment
helm upgrade searxng searxng/searxng -f searxng-values.yaml -n vllm-inference

# Verify HPA is working
kubectl get hpa -n vllm-inference
```

**Monitoring**:
```bash
# Watch HPA scaling decisions
kubectl describe hpa searxng -n vllm-inference

# Monitor pod scaling
watch kubectl get pods -n vllm-inference | grep searxng
```

### 2. Optimize Search Engine Selection

**Current Issue**: Too many search engines can cause timeouts and resource exhaustion.

**Recommended Configuration**:
```yaml
searxng:
  config:
    engines:
      # Keep only fast, reliable engines
      - name: google
        disabled: false
        weight: 1.0
      - name: bing
        disabled: false
        weight: 0.8
      - name: duckduckgo
        disabled: false
        weight: 0.9
      
      # Disable slower engines temporarily
      - name: google scholar
        disabled: true
      - name: semantic scholar
        disabled: true
      - name: startpage
        disabled: true
      
      # Keep essential technical sources
      - name: stackoverflow
        disabled: false
        weight: 0.9
      - name: github
        disabled: false
        weight: 0.8
```

**Benefits**:
- Faster response times
- Reduced resource usage
- Lower chance of timeouts

### 3. Configure Request Throttling in OpenWebUI

**Update HR Tenant Configuration**:

In `setup-openwebui/hr/templates/values.yaml.tpl`, add:
```yaml
extraEnvVars:
  # Existing SearXNG configuration...
  
  # Add request throttling
  - name: "RAG_WEB_SEARCH_CONCURRENT_REQUESTS"
    value: "3"  # Reduced from 10
  - name: "RAG_WEB_SEARCH_REQUEST_TIMEOUT"
    value: "30"  # Add timeout
  - name: "RAG_WEB_SEARCH_DELAY_BETWEEN_REQUESTS"
    value: "1"   # 1 second delay between requests
```

**Benefits**:
- Prevents request bursts from individual OpenWebUI instances
- Reduces load on SearXNG
- Improves overall system stability

## Advanced Optimizations (Low Priority)

### 1. Redis Cache Tuning

**Current Configuration**:
```yaml
redis:
  master:
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"
```

**Optimized Configuration**:
```yaml
redis:
  master:
    resources:
      requests:
        cpu: "200m"
        memory: "512Mi"  # 4x increase for better caching
      limits:
        cpu: "500m"
        memory: "1Gi"    # 4x increase
    persistence:
      enabled: true      # Enable persistence for cache retention
      size: 2Gi
```

**Cache Configuration**:
```yaml
searxng:
  config:
    redis:
      url: "redis://searxng-redis:6379/0"
    outgoing:
      # Increase connection pooling
      pool_connections: 200  # Increased from 100
      pool_maxsize: 50       # Increased from 20
```

### 2. Search Timeout Optimization

**Configuration**:
```yaml
searxng:
  config:
    search:
      search_timeout: 15.0    # Increased from 10.0
    outgoing:
      request_timeout: 15.0   # Increased from 10.0
      max_request_timeout: 20.0  # Increased from 15.0
```

### 3. Connection Pool Optimization

**Configuration**:
```yaml
searxng:
  config:
    outgoing:
      pool_connections: 200
      pool_maxsize: 50
      enable_http2: true
      # Add keep-alive settings
      keep_alive: true
      keep_alive_timeout: 30
```
