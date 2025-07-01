# Domain Setup for Multi-Tenant OpenWebUI

> **🌐 Step 7**: Link custom domains to your OpenWebUI load balancers  
> **Prerequisites**: ✅ Infrastructure Setup, ✅ OpenWebUI Deployment

## Current Situation

Right now, each of your three OpenWebUI tenants (HR, Legal, US) is accessible through auto-generated AWS Network Load Balancer DNS names that look like:

```
k8s-hrwebui-openwebu-abc123.elb.ap-southeast-3.amazonaws.com
k8s-legalwe-openwebu-def456.elb.ap-southeast-3.amazonaws.com  
k8s-uswebui-openwebu-ghi789.elb.ap-southeast-3.amazonaws.com
```

These work perfectly fine, but they're not user-friendly or brandable.

## Goal

We want users to access your OpenWebUI tenants through custom domain names like:

```
hr.company.com
legal.company.com
us.company.com
```

## Two Methods to Achieve This

### Method 1: Route 53 + ALIAS Records (Manual Approach)

**How it works conceptually:**

1. **You create a Route 53 hosted zone** for your domain (company.com)
2. **You get the current NLB DNS names** from each tenant's load balancer
3. **You create ALIAS records** in Route 53 that point your custom domains to the NLB DNS names
4. **DNS resolution happens**: When someone visits hr.company.com, Route 53 resolves it to the NLB DNS name, which then routes to your OpenWebUI

**When you would use this:**
- You're already using AWS Route 53 for DNS
- You have a small number of domains to manage
- You prefer having full control over DNS records
- You want the most cost-effective solution
- You don't mind manually updating DNS records when load balancers change

**How you would deploy this:**
1. Create Route 53 hosted zone for your domain
2. Run a script to get all your current NLB DNS names
3. Create ALIAS records pointing hr.company.com → NLB DNS name
4. Repeat for legal.company.com and us.company.com
5. Optionally set up SSL certificates through AWS Certificate Manager
6. Test that domains resolve correctly

### Method 2: External DNS Controller (Automated Approach)

**How it works conceptually:**

1. **You deploy a controller** (External DNS) inside your EKS cluster
2. **You add annotations** to your existing Kubernetes services specifying what domain names you want
3. **The controller watches** your services and automatically creates/updates DNS records
4. **Everything stays in sync**: If load balancers change, the controller automatically updates DNS records

**When you would use this:**
- You want full automation with no manual DNS management
- You use multiple DNS providers (not just Route 53)
- You have many domains or frequently changing infrastructure
- You prefer GitOps-style management where DNS is controlled by Kubernetes manifests
- You don't mind running an additional controller in your cluster

**How you would deploy this:**
1. Deploy the External DNS controller in your EKS cluster
2. Configure it with credentials for your DNS provider (Route 53, CloudFlare, etc.)
3. Add annotations to your existing load balancer services specifying domain names
4. The controller automatically creates DNS records
5. Set up certificate management (cert-manager) for automatic SSL certificates
6. Monitor the controller logs to ensure DNS records are being created correctly

## Which Method Should You Choose?

**Choose Method 1 (Route 53 + ALIAS) if:**
- You're using AWS Route 53
- You have 3-10 domains to manage
- You prefer simplicity and lower costs
- You're comfortable with occasional manual updates

**Choose Method 2 (External DNS) if:**
- You want zero manual DNS management
- You use non-AWS DNS providers
- You have many domains or dynamic infrastructure
- You prefer everything managed through Kubernetes

## SSL/TLS Certificates

Both methods support adding SSL certificates so users can access your sites via HTTPS:

**With Method 1:** Use AWS Certificate Manager to get free SSL certificates
**With Method 2:** Use cert-manager with Let's Encrypt for free automatic SSL certificates

## What Happens After Setup

Once you complete either method:

1. **Users access friendly URLs**: hr.company.com instead of long NLB names
2. **SSL encryption works**: HTTPS with valid certificates
3. **Everything else stays the same**: Your multi-tenant architecture, authentication, etc.
4. **Maintenance varies**: Method 1 requires occasional manual updates, Method 2 is fully automated

## Next Steps

1. **Decide which method** fits your organization's needs
2. **Prepare your domain**: Ensure you have admin access to your DNS provider
3. **Choose your domain pattern**: Subdomains (hr.company.com) vs paths (company.com/hr)
4. **Plan SSL strategy**: AWS Certificate Manager vs Let's Encrypt vs custom certificates

Both methods are proven, reliable approaches that will give you professional, branded access to your OpenWebUI tenants while maintaining all the security and isolation you've already built.
