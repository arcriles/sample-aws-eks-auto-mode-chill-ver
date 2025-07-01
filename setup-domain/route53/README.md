# Method 1: Route 53 + ALIAS Records

> **🎯 Manual DNS Management Approach**  
> **Best for**: AWS-native setups, cost-conscious deployments, full DNS control

## Overview

This method uses AWS Route 53 to create ALIAS records that point your custom domains directly to your Network Load Balancer DNS names. It's the most straightforward approach if you're already using AWS infrastructure.

## How It Works

```
User visits hr.company.com
    ↓
Route 53 resolves ALIAS record
    ↓
Points to k8s-hrwebui-openwebu-abc123.elb.ap-southeast-3.amazonaws.com
    ↓
AWS Network Load Balancer routes traffic
    ↓
OpenWebUI in hr-webui namespace
```

## Step-by-Step Deployment Process

### Step 1: Prepare Your Domain
1. **Own a domain** (e.g., company.com)
2. **Have AWS Route 53 access** with appropriate permissions
3. **Decide on subdomain structure**:
   - hr.company.com
   - legal.company.com  
   - us.company.com

### Step 2: Create Route 53 Hosted Zone
1. **Go to AWS Route 53 console**
2. **Create hosted zone** for your domain (company.com)
3. **Note the name servers** - you'll need to update these with your domain registrar
4. **Update your domain registrar** to use Route 53 name servers

### Step 3: Get Your Load Balancer DNS Names
1. **Check each tenant's load balancer**:
   ```bash
   kubectl get svc -n hr-webui open-webui-service
   kubectl get svc -n legal-webui open-webui-service  
   kubectl get svc -n us-webui open-webui-service
   ```
2. **Copy the EXTERNAL-IP values** (these are your NLB DNS names)
3. **Test direct access** to ensure load balancers are working

### Step 4: Create ALIAS Records
For each tenant, create an ALIAS record in Route 53:

1. **Go to your hosted zone** in Route 53 console
2. **Create record** with these settings:
   - **Record name**: hr (for hr.company.com)
   - **Record type**: A
   - **Alias**: Yes
   - **Route traffic to**: Alias to Network Load Balancer
   - **Region**: Your EKS region (e.g., ap-southeast-3)
   - **Load balancer**: Select your HR tenant's NLB
3. **Repeat for legal and us tenants**

### Step 5: Set Up SSL Certificates (Optional but Recommended)
1. **Go to AWS Certificate Manager**
2. **Request public certificate** for:
   - hr.company.com
   - legal.company.com
   - us.company.com
   - Or use wildcard: *.company.com
3. **Use DNS validation** (easiest with Route 53)
4. **Wait for certificate validation**

### Step 6: Configure Load Balancers for HTTPS (If Using SSL)
1. **Modify your load balancer services** to support HTTPS
2. **Add SSL certificate ARN** to load balancer annotations
3. **Update port configurations** for HTTPS (443)

### Step 7: Test Your Setup
1. **Wait for DNS propagation** (usually 5-15 minutes)
2. **Test domain resolution**:
   ```bash
   nslookup hr.company.com
   dig hr.company.com
   ```
3. **Test web access**:
   ```bash
   curl -I http://hr.company.com
   curl -I https://hr.company.com  # if using SSL
   ```
4. **Verify all three tenants** work correctly

## Advantages of This Method

### Cost Effective
- **No additional controllers** running in your cluster
- **Only Route 53 costs**: ~$0.50/month per hosted zone + query costs
- **Free SSL certificates** with AWS Certificate Manager

### Simple and Reliable
- **AWS-native solution** with high availability
- **Direct DNS resolution** - no additional hops
- **Integrated health checks** with ALIAS records

### Full Control
- **Manual DNS management** - you control exactly what happens
- **Easy troubleshooting** - clear DNS resolution path
- **No dependencies** on cluster controllers

## Disadvantages of This Method

### Manual Maintenance
- **Load balancer changes** require manual DNS updates
- **New tenants** need manual DNS record creation
- **No automation** - everything is manual process

### AWS Route 53 Only
- **Locked to Route 53** - can't use other DNS providers
- **AWS dependency** for DNS management

### Limited Scalability
- **Manual work increases** with more tenants/domains
- **Human error potential** in manual processes

## When Load Balancers Change

If your EKS cluster is recreated or load balancers change:

1. **Get new NLB DNS names** from Kubernetes services
2. **Update ALIAS records** in Route 53 to point to new NLB names
3. **Wait for DNS propagation**
4. **Test connectivity** to ensure everything works

## Maintenance Tasks

### Regular Monitoring
- **Check certificate expiration** (ACM auto-renews, but monitor)
- **Verify DNS resolution** periodically
- **Monitor load balancer health**

### When Adding New Tenants
1. **Deploy new tenant** following existing OpenWebUI setup
2. **Get new tenant's NLB DNS name**
3. **Create new ALIAS record** in Route 53
4. **Add domain to SSL certificate** (or request new certificate)
5. **Test new tenant access**

This method provides a solid, AWS-native foundation for domain management that scales well for small to medium deployments while keeping costs low and complexity minimal.
