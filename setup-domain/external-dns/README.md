# Method 2: External DNS Controller

> **🤖 Automated DNS Management Approach**  
> **Best for**: Multi-cloud setups, automation-focused deployments, GitOps workflows

## Overview

This method deploys an External DNS controller inside your EKS cluster that automatically manages DNS records based on Kubernetes service annotations. It provides full automation and supports multiple DNS providers beyond just AWS Route 53.

## How It Works

```
External DNS Controller (running in EKS)
    ↓ (watches services with annotations)
Kubernetes Service with external-dns.alpha.kubernetes.io/hostname annotation
    ↓ (automatically creates/updates DNS records)
DNS Provider API (Route 53, CloudFlare, Google DNS, etc.)
    ↓ (DNS resolution)
User visits hr.company.com → NLB → OpenWebUI
```

## Step-by-Step Deployment Process

### Step 1: Choose Your DNS Provider
External DNS supports 20+ DNS providers:
- **AWS Route 53** (most common with EKS)
- **CloudFlare** (popular for performance)
- **Google Cloud DNS**
- **Azure DNS**
- **DigitalOcean DNS**
- **And many more...**

### Step 2: Set Up DNS Provider Access
**For AWS Route 53:**
1. **Create IAM policy** with Route 53 permissions
2. **Create IAM role** for External DNS controller
3. **Set up Pod Identity** or IRSA for secure access

**For Other Providers:**
1. **Get API credentials** from your DNS provider
2. **Create Kubernetes secret** with credentials
3. **Configure External DNS** to use the secret

### Step 3: Deploy External DNS Controller
1. **Create namespace** for External DNS
2. **Deploy the controller** with appropriate configuration
3. **Configure RBAC** permissions for the controller
4. **Set up monitoring** to watch controller logs

### Step 4: Add Domain Annotations to Your Services
For each tenant's load balancer service, add annotations:

**HR Tenant Example:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: open-webui-service
  namespace: hr-webui
  annotations:
    # Existing NLB annotations
    service.beta.kubernetes.io/aws-load-balancer-type: external
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    
    # New External DNS annotations
    external-dns.alpha.kubernetes.io/hostname: hr.company.com
    external-dns.alpha.kubernetes.io/ttl: "300"
spec:
  # ... rest of service configuration stays the same
```

### Step 5: Apply Updated Service Configurations
1. **Update each tenant's service** with domain annotations
2. **Apply the changes** to your cluster:
   ```bash
   kubectl apply -f setup-openwebui/hr/lb.yaml
   kubectl apply -f setup-openwebui/legal/lb.yaml  
   kubectl apply -f setup-openwebui/us/lb.yaml
   ```
3. **Watch External DNS logs** to see DNS records being created

### Step 6: Set Up Automatic SSL Certificates (Optional)
1. **Deploy cert-manager** in your cluster
2. **Configure Let's Encrypt issuer** for free SSL certificates
3. **Add certificate annotations** to your services
4. **Certificates are automatically** requested and renewed

### Step 7: Monitor and Verify
1. **Check External DNS logs**:
   ```bash
   kubectl logs -n external-dns deployment/external-dns
   ```
2. **Verify DNS records** were created in your DNS provider
3. **Test domain resolution**:
   ```bash
   nslookup hr.company.com
   dig hr.company.com
   ```
4. **Test web access** to all three tenants

## Advantages of This Method

### Full Automation
- **Zero manual DNS management** - everything is automated
- **Self-healing** - automatically fixes DNS drift
- **GitOps friendly** - DNS changes via Kubernetes manifests

### Multi-Provider Support
- **20+ DNS providers** supported
- **Not locked to AWS** - use any DNS provider
- **Hybrid cloud ready** - works across cloud providers

### Scalability
- **Handles hundreds of domains** automatically
- **New tenants** automatically get DNS records
- **No human intervention** needed for routine changes

### Integration
- **Works with cert-manager** for automatic SSL
- **Integrates with Ingress controllers**
- **Supports advanced DNS features** (weighted routing, etc.)

## Disadvantages of This Method

### Additional Complexity
- **Another controller** to manage and monitor
- **More moving parts** - potential failure points
- **Learning curve** for External DNS concepts

### Resource Overhead
- **Controller consumes** cluster resources (CPU, memory)
- **Additional monitoring** required
- **Dependency** on controller health

### Potential Conflicts
- **DNS record conflicts** if misconfigured
- **Requires careful planning** of DNS ownership
- **Debugging** can be more complex

## Supported DNS Providers

### Cloud Providers
- **AWS Route 53** ✅
- **Google Cloud DNS** ✅
- **Azure DNS** ✅
- **DigitalOcean DNS** ✅
- **Linode DNS** ✅

### CDN/Performance Providers
- **CloudFlare** ✅
- **Fastly** ✅
- **NS1** ✅

### Enterprise Providers
- **Infoblox** ✅
- **PowerDNS** ✅
- **Designate (OpenStack)** ✅

### And Many More...
- **Akamai Edge DNS** ✅
- **Oracle Cloud DNS** ✅
- **Vultr DNS** ✅

## When Load Balancers Change

The beauty of External DNS is that it handles changes automatically:

1. **EKS recreates load balancers** with new DNS names
2. **External DNS detects the change** automatically
3. **DNS records are updated** without human intervention
4. **No manual work required** - everything stays in sync

## Maintenance Tasks

### Regular Monitoring
- **Watch External DNS logs** for errors
- **Monitor DNS provider quotas** and rate limits
- **Check certificate renewals** (if using cert-manager)

### When Adding New Tenants
1. **Deploy new tenant** following existing OpenWebUI setup
2. **Add domain annotation** to new tenant's service
3. **External DNS automatically** creates DNS record
4. **No manual DNS work** required

### Controller Updates
- **Update External DNS** periodically for security patches
- **Test in staging** before production updates
- **Monitor for breaking changes** in new versions

## Advanced Features

### Weighted DNS Routing
- **Traffic splitting** between different versions
- **Blue-green deployments** with DNS
- **Canary releases** using DNS weights

### Geographic DNS Routing
- **Route users** to nearest data center
- **Disaster recovery** with DNS failover
- **Multi-region deployments**

### Custom DNS Records
- **TXT records** for domain verification
- **CNAME records** for aliases
- **MX records** for email routing

This method provides enterprise-grade automation and flexibility, making it ideal for organizations that want to eliminate manual DNS management and support complex, multi-cloud deployments.
