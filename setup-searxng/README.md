# SearXNG Setup - HR Tenant Only

> **⚠️ IMPORTANT**: This setup is **exclusively for the HR tenant**. Legal and US tenants do not include web search capabilities.

> **🔍 Step 5 of 5**: Complete this ONLY if you deployed the HR tenant and need web search functionality.

## Overview

This directory contains the configuration files for setting up SearXNG as a privacy-focused web search engine exclusively for the **HR tenant**. SearXNG provides web search capabilities for the HR OpenWebUI deployment, enabling real-time web data integration with HR team's AI chat interface.

## What is SearXNG?

SearXNG is a free internet metasearch engine that:
- **Aggregates results** from various search services and databases
- **Protects privacy** - users are neither tracked nor profiled
- **Provides JSON API** - perfect for AI integration
- **Supports 1000+ search engines** - comprehensive search coverage
- **Offers caching** - improved performance with Redis

## Architecture

SearXNG is deployed as a shared service with the following components:

- **SearXNG Engine**: Main metasearch service that aggregates results
- **Redis Cache**: Optional caching for improved search performance
- **Internal Service**: Kubernetes service for OpenWebUI communication
- **JSON API**: Optimized endpoint for AI integration

## Prerequisites

Before deploying SearXNG, ensure you have:

1. ✅ **Completed**: Main Terraform infrastructure deployment ([see main README](../README.md))
2. ✅ **Completed**: HR tenant deployment ([see OpenWebUI README](../setup-openwebui/))
3. ✅ **Verified**: HR OpenWebUI is running in `hr-webui` namespace
4. ✅ **Completed**: LiteLLM setup ([see LiteLLM README](../setup-litellm/))

## Deployment Steps

### 1. Navigate to SearXNG Directory

```bash
cd setup-searxng
```

### 2. Add SearXNG Helm Repository

```bash
# Add the SearXNG Helm repository
helm repo add searxng https://charts.searxng.org
helm repo update
```

### 3. Deploy SearXNG

```bash
# Deploy SearXNG with optimized configuration
helm install searxng searxng/searxng -f searxng-values.yaml -n vllm-inference
```

> **Note**: SearXNG is deployed in the same `vllm-inference` namespace as OpenWebUI and Tika for easy service discovery.

### 4. Verify Deployment

Check that SearXNG is running correctly:

```bash
# Check pods
kubectl get pods -n vllm-inference | grep searxng

# Check services
kubectl get svc -n vllm-inference | grep searxng

# Check SearXNG logs
kubectl logs deployment/searxng -n vllm-inference
```
## Configuration Details

### SearXNG Configuration

The `searxng-values.yaml` file includes optimized settings for OpenWebUI integration:

- **JSON Format Enabled**: Required for OpenWebUI API integration
- **Redis Caching**: Improved performance for repeated searches
- **Security Settings**: Hardened configuration for production use
- **Search Engines**: Optimized selection of search providers
- **Rate Limiting**: Configured to handle OpenWebUI requests

### OpenWebUI Integration

Once configured, OpenWebUI will:
- **Enable Web Search Toggle**: Users can turn web search on/off per conversation
- **Integrate Results**: Web search results are included in AI responses
- **Maintain Privacy**: No user tracking through SearXNG
- **Cache Results**: Redis caching improves response times

## Testing Web Search (HR Tenant Only)

### 1. Access HR OpenWebUI

Get your HR tenant's OpenWebUI URL:

```bash
# Get the HR tenant's load balancer URL
export HR_OPENWEBUI_URL=$(kubectl get service open-webui-service -n hr-webui -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "HR OpenWebUI is available at: http://$HR_OPENWEBUI_URL"
```

### 2. Enable Web Search in Chat

1. **Open OpenWebUI** in your browser
2. **Go to Admin Settings**
3. **Go to Web Search**
4. **Enable Web Search**
5. **Select searxng for Web Search Engine**
6. **Click Save**

### 3. Test Different Queries

Try various types of searches to verify functionality:

```
Current Events: "What happened in the stock market today?"
Technical Info: "Latest Python 3.12 features"
Recent News: "Recent developments in renewable energy"
Factual Data: "Current population of Tokyo"
```

### 4. Verify Search Integration

You should see:
- ✅ **Web Search Toggle**: Available in chat interface
- ✅ **Enhanced Responses**: AI answers include web data
- ✅ **Current Information**: Up-to-date results from the web
- ✅ **Source Attribution**: References to web sources in responses

## HR-Only Integration

SearXNG is configured exclusively for the HR tenant:


### Configuration:
- **HR Integration**: Only HR tenant's `values.yaml` includes SearXNG environment variables
- **Shared Service**: SearXNG deployed in `vllm-inference` namespace for efficient resource usage
- **Secure Access**: Internal-only service accessible by HR OpenWebUI pods

## Corporate Proxy Configuration

If your organization requires all outbound internet traffic to go through a corporate proxy server, you can configure SearXNG to route all search engine requests through your proxy infrastructure.

### Configuration Steps

1. **Identify Your Proxy Details**
   
   Gather the following information from your network administrator:
   - Proxy server hostname or IP address
   - Proxy port number (commonly 8080, 3128, or 8888)
   - Authentication requirements (username/password if needed)
   - Protocol support (HTTP/HTTPS/SOCKS5)

2. **Edit the Values File**
   
   Open the `searxng-values.yaml` file and locate the `Corporate Proxy Configuration` section under `searxng.config.outgoing`.

3. **Choose Your Configuration**

   **For Basic Proxy (no authentication):**
   ```yaml
   outgoing:
     proxies:
       http:
         - http://your-proxy-server.company.com:8080
       https:
         - http://your-proxy-server.company.com:8080
   ```

   **For Authenticated Proxy:**
   ```yaml
   outgoing:
     proxies:
       http:
         - http://username:password@your-proxy-server.company.com:8080
       https:
         - http://username:password@your-proxy-server.company.com:8080
   ```

   **For Multiple Proxy Servers (failover/load balancing):**
   ```yaml
   outgoing:
     proxies:
       http:
         - http://proxy1.company.com:8080
         - http://proxy2.company.com:8080
       https:
         - http://proxy1.company.com:8080
         - http://proxy2.company.com:8080
   ```

4. **Uncomment and Modify**
   
   - Remove the `#` characters from the beginning of the relevant lines
   - Replace the example values with your actual proxy server details
   - Save the file

5. **Deploy or Update SearXNG**
   
   If SearXNG is not yet deployed:
   ```bash
   helm install searxng searxng/searxng -f searxng-values.yaml -n vllm-inference
   ```
   
   If SearXNG is already running:
   ```bash
   helm upgrade searxng searxng/searxng -f searxng-values.yaml -n vllm-inference
   ```

### Configuration Options

**Basic Settings:**
- `proxies`: Define HTTP and HTTPS proxy servers
- `using_tor_proxy`: Set to `true` if using Tor (rarely needed in corporate environments)
- `extra_proxy_timeout`: Additional timeout for proxy connections (default: 0)

**Advanced Options:**
- **SOCKS5 Proxy**: Use `socks5://proxy-server:port` format if your organization uses SOCKS5
- **Per-Engine Proxy**: Configure different proxies for specific search engines (advanced use case)
- **Source IP**: Specify source IP addresses if you have multiple network interfaces

### Security Considerations

- **Credential Security**: Avoid hardcoding usernames/passwords in configuration files
- **Network Isolation**: Ensure SearXNG can only access approved proxy servers
- **Monitoring**: Corporate proxies will log all search engine requests
- **Performance**: Proxy routing may add latency to search requests

### Important Notes

- **All Search Engines**: The proxy configuration applies to ALL configured search engines
- **Internal Services**: The proxy only affects outbound requests to external search engines
- **Redis Cache**: Proxy settings do not affect internal Redis cache connections
- **Health Checks**: Kubernetes health checks are not affected by proxy settings

## Redis Cache Configuration

SearXNG includes an integrated Redis cache to improve search performance and reduce load on external search engines. Understanding the Redis configuration helps with monitoring, troubleshooting, and optimization.

### What is Redis in SearXNG?

Redis serves as an in-memory cache for SearXNG, providing:
- **Search Result Caching**: Stores frequently requested search results for faster retrieval
- **Performance Optimization**: Reduces repeated calls to external search engines
- **Rate Limiting Support**: Helps manage request throttling and API limits
- **Session Management**: Temporary storage for search metadata and user sessions

### Deployment Architecture

**Pod-Based Deployment (Not AWS ElastiCache):**
- Redis runs as a **Kubernetes pod** within your EKS cluster
- **Internal service** accessible only within the cluster
- **No external dependencies** or additional AWS service charges
- **Co-located** with SearXNG for ultra-low latency access

**Service Configuration:**
```yaml
redis:
  enabled: true
  auth:
    enabled: false  # Simplified for internal cluster use
  master:
    persistence:
      enabled: false  # Ephemeral cache - no persistent storage
  replica:
    replicaCount: 0  # Single Redis instance
```

### Resource Allocation

**Current Resource Configuration:**
```yaml
resources:
  requests:
    cpu: "100m"      # 0.1 CPU cores reserved
    memory: "128Mi"  # 128 MiB memory reserved
  limits:
    cpu: "200m"      # Maximum 0.2 CPU cores
    memory: "256Mi"  # Maximum 256 MiB memory
```

**Resource Justification:**
- **CPU**: 100m-200m is sufficient for SearXNG's caching workload
- **Memory**: 128-256Mi provides adequate cache space for search results
- **Lightweight**: Optimized for cost-effectiveness in EKS Auto Mode
- **Scalable**: Can be increased if higher cache hit rates are needed

### Configuration Details

**Connection Settings:**
- **Service Name**: `searxng-redis`
- **Port**: `6379` (standard Redis port)
- **Database**: `0` (default Redis database)
- **Connection URL**: `redis://searxng-redis:6379/0`

**Security Configuration:**
- **Authentication**: Disabled (internal cluster security)
- **Network Access**: Internal cluster only (not externally accessible)
- **Encryption**: Not required for internal cluster communication

**Storage Configuration:**
- **Persistence**: Disabled (cache data is ephemeral)
- **Data Retention**: Cache cleared on pod restart
- **Backup**: Not applicable (cache data is replaceable)

### Performance Impact

**Cache Benefits:**
- **Faster Response Times**: Cached results return in milliseconds
- **Reduced External API Calls**: Fewer requests to Google, Bing, etc.
- **Lower Latency**: In-cluster cache access vs. external API calls
- **Cost Optimization**: Reduced API usage and bandwidth

**Cache Behavior:**
```
Search Request → Check Redis Cache
                      ↓
              Cache Hit (Fast): Return cached results
                      ↓
              Cache Miss: Query search engines → Cache results → Return to user
```

### Customization Options

**Increase Resources (if needed):**
```yaml
redis:
  master:
    resources:
      requests:
        cpu: "200m"      # Increase if CPU usage is high
        memory: "256Mi"  # Increase for larger cache
      limits:
        cpu: "500m"      # Higher limit for burst capacity
        memory: "512Mi"  # More memory for cache storage
```

**Enable Persistence (optional):**
```yaml
redis:
  master:
    persistence:
      enabled: true
      size: 1Gi  # Persistent storage size
```

**Add Authentication (enhanced security):**
```yaml
redis:
  auth:
    enabled: true
    password: "your-secure-password"
```

### When to Modify Redis Configuration

**Increase Resources When:**
- Redis pod shows high CPU or memory usage
- Cache hit rates are low due to memory constraints
- Search response times are slower than expected
- Multiple users are experiencing performance issues

**Enable Persistence When:**
- You want to retain cache across pod restarts
- Search patterns are predictable and benefit from long-term caching
- You have available persistent storage in your cluster

**Add Replication When:**
- High availability is critical for your search functionality
- You need to distribute cache load across multiple Redis instances
- Your cluster has multiple availability zones

## Performance Optimization

### Redis Caching

SearXNG is configured with Redis caching for:
- **Faster Responses**: Cached search results return immediately
- **Reduced Load**: Less load on external search engines
- **Better UX**: Improved response times for users

### Resource Limits

The deployment includes appropriate resource limits:
- **CPU**: Optimized for search processing
- **Memory**: Sufficient for caching and operations
- **Replicas**: Can be scaled based on usage

### Search Engine Selection

The configuration includes optimized search engines:
- **General Search**: Google, Bing, DuckDuckGo
- **Academic**: Google Scholar, Semantic Scholar
- **News**: Various news sources
- **Technical**: Stack Overflow, GitHub

## Security Considerations

### Privacy Protection
- **No User Tracking**: SearXNG doesn't track or profile users
- **No Data Retention**: Search queries are not stored
- **Anonymous Requests**: All searches are anonymous

### Network Security
- **Internal Only**: SearXNG is not exposed externally
- **Service Mesh**: Communication within Kubernetes cluster
- **No External Access**: Only accessible by OpenWebUI pods

### Configuration Security
- **Hardened Settings**: Security-focused configuration
- **Rate Limiting**: Protection against abuse
- **Resource Limits**: Prevents resource exhaustion

## Troubleshooting

### Common Issues

#### 1. Web Search Not Available in OpenWebUI

**Symptoms**: No web search toggle in chat interface

**Solutions**:
```bash
# Check OpenWebUI environment variables
kubectl describe deployment open-webui -n vllm-inference | grep -A 20 "Environment:"

# Verify SearXNG service is running
kubectl get svc searxng -n vllm-inference

# Check OpenWebUI logs
kubectl logs deployment/open-webui -n vllm-inference | grep -i search
```

#### 2. SearXNG Service Not Responding

**Symptoms**: Web search toggle available but no results

**Solutions**:
```bash
# Check SearXNG pod status
kubectl get pods -n vllm-inference | grep searxng

# Check SearXNG logs
kubectl logs deployment/searxng -n vllm-inference

# Test SearXNG directly
kubectl exec -it deployment/open-webui -n vllm-inference -- curl "http://searxng.vllm-inference.svc.cluster.local:8080/search?q=test&format=json"
```

#### 3. Slow Search Responses

**Symptoms**: Web search takes too long to respond

**Solutions**:
```bash
# Check Redis cache status
kubectl get pods -n vllm-inference | grep redis

# Monitor SearXNG performance
kubectl top pods -n vllm-inference | grep searxng

# Check resource usage
kubectl describe pod <searxng-pod-name> -n vllm-inference
```

### Debugging Commands

```bash
# Get all SearXNG resources
kubectl get all -n vllm-inference | grep searxng

# Check SearXNG configuration
kubectl get configmap -n vllm-inference | grep searxng

# View SearXNG service details
kubectl describe service searxng -n vllm-inference

# Check network connectivity
kubectl exec -it deployment/open-webui -n vllm-inference -- nslookup searxng.vllm-inference.svc.cluster.local
```

## Cleanup

To remove SearXNG:

```bash
# Remove SearXNG deployment
helm uninstall searxng -n vllm-inference

# Remove any remaining resources
kubectl delete all -l app.kubernetes.io/name=searxng -n vllm-inference
```

To disable web search in OpenWebUI without removing SearXNG:

```bash
# Update OpenWebUI to disable web search
helm upgrade open-webui open-webui/open-webui -f values.yaml -n vllm-inference --reuse-values --set extraEnvVars[0].name="ENABLE_RAG_WEB_SEARCH" --set extraEnvVars[0].value="False"
```

## Completion

🎉 **Setup Complete!** You now have a fully functional EKS Auto Mode AI platform with:

- **✅ Infrastructure**: EKS cluster with Auto Mode features
- **✅ Custom Branding**: GAR GPT branded OpenWebUI
- **✅ Document Processing**: S3 storage, PostgreSQL vectors, Apache Tika
- **✅ Multi-Provider LLM**: LiteLLM gateway with cost tracking
- **✅ Web Search**: SearXNG integration for real-time web data

### Your Complete AI Platform Features:

🤖 **AI Chat Interface**
- Custom GAR GPT branding
- Multi-provider LLM access
- Document upload and processing
- Real-time web search integration

📊 **Enterprise Features**
- Cost tracking and usage analytics
- Multi-tenant support
- Secure credential management
- Scalable infrastructure

🔒 **Security & Privacy**
- AWS Secrets Manager integration
- Pod Identity for secure access
- Privacy-focused web search
- No user tracking or profiling

🚀 **Production Ready**
- Auto-scaling with Karpenter
- Load balancer configuration
- Redis caching for performance
- Comprehensive monitoring

Your AI platform is now ready for production workloads with enterprise-grade security, scalability, cost optimization, and comprehensive AI capabilities including document processing and web search.

**👉 Next Step: [Setup Observability](../setup-o11y/)** - Add comprehensive monitoring and cost observability to your AI platform.

## Support

For issues and questions:
- Check the [SearXNG documentation](https://docs.searxng.org/)
- Review the [OpenWebUI web search guide](https://docs.openwebui.com/)
- Verify all prerequisites are met
- Follow the sequential setup flow
- Check troubleshooting steps above
