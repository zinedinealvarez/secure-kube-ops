param(
  [string]$GhcrUsername = $env:GHCR_USERNAME,
  [string]$GhcrToken = $env:GHCR_TOKEN,
  [string]$GrafanaAdminUser = $env:GRAFANA_ADMIN_USER,
  [string]$GrafanaAdminPassword = $env:GRAFANA_ADMIN_PASSWORD,
  [switch]$SkipApplication,
  [switch]$SkipJuiceShop,
  [switch]$SkipMonitoring,
  [switch]$SkipRuntimeSecurity,
  [switch]$IncludeWaf,
  [switch]$SkipHelmRepoUpdate
)

$ErrorActionPreference = "Stop"

function Ensure-Command {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command '$Name' was not found in PATH."
  }
}

function Invoke-Step {
  param(
    [string]$Name,
    [scriptblock]$Action
  )

  Write-Host ""
  Write-Host "==> $Name"
  & $Action
}

Ensure-Command "kubectl"
Ensure-Command "helm"

Invoke-Step "Checking Kubernetes context" {
  kubectl config current-context
  kubectl get nodes
}

if (-not $SkipApplication) {
  Invoke-Step "Deploying reference application namespace" {
    kubectl apply -f k8s/application/namespace.yaml
  }

  if (-not [string]::IsNullOrWhiteSpace($GhcrUsername) -and -not [string]::IsNullOrWhiteSpace($GhcrToken)) {
    Invoke-Step "Creating or updating GHCR imagePullSecret" {
      kubectl create secret docker-registry ghcr-pull-secret `
        --namespace application `
        --docker-server=ghcr.io `
        --docker-username=$GhcrUsername `
        --docker-password=$GhcrToken `
        --dry-run=client `
        -o yaml | kubectl apply -f -
    }
  } else {
    Write-Host "GHCR credentials not provided. Skipping ghcr-pull-secret creation."
    Write-Host "Set GHCR_USERNAME and GHCR_TOKEN if the image is private."
  }

  Invoke-Step "Deploying reference application" {
    kubectl apply -f k8s/application/deployment.yaml
    kubectl apply -f k8s/application/service.yaml
    kubectl rollout status deployment/secure-kube-ops -n application
  }
}

if (-not $SkipJuiceShop) {
  Invoke-Step "Deploying OWASP Juice Shop lab" {
    kubectl apply -k k8s/labs/juice-shop
    kubectl rollout status deployment/juice-shop -n vulnerable-lab
  }
}

if (-not $SkipMonitoring) {
  Invoke-Step "Preparing monitoring namespace" {
    kubectl apply -f k8s/monitoring/namespace.yaml
  }

  if ([string]::IsNullOrWhiteSpace($GrafanaAdminUser) -or [string]::IsNullOrWhiteSpace($GrafanaAdminPassword)) {
    throw "Grafana credentials are required because k8s/monitoring/values.yaml uses the Secret 'monitoring-grafana-admin'. Set GRAFANA_ADMIN_USER and GRAFANA_ADMIN_PASSWORD."
  }

  Invoke-Step "Creating or updating Grafana admin Secret" {
    kubectl create secret generic monitoring-grafana-admin `
      --namespace monitoring `
      --from-literal=admin-user=$GrafanaAdminUser `
      --from-literal=admin-password=$GrafanaAdminPassword `
      --dry-run=client `
      -o yaml | kubectl apply -f -
  }

  if (-not $SkipHelmRepoUpdate) {
    Invoke-Step "Adding and updating Prometheus Community Helm repository" {
      helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
      helm repo update
    }
  }

  Invoke-Step "Installing or updating kube-prometheus-stack" {
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
      --namespace monitoring `
      --version 84.5.0 `
      -f k8s/monitoring/values.yaml
  }

  Invoke-Step "Installing or updating Pushgateway" {
    helm upgrade --install pushgateway prometheus-community/prometheus-pushgateway `
      --namespace monitoring `
      --version 3.6.0 `
      -f k8s/monitoring/pushgateway-values.yaml
  }

  Invoke-Step "Applying dashboards and Pushgateway ServiceMonitor" {
    kubectl apply -f k8s/monitoring/pushgateway-servicemonitor.yaml
    kubectl apply -f k8s/monitoring/dashboards/grafana-dashboard-securekubeops-cluster-overview.yaml
    kubectl apply -f k8s/monitoring/dashboards/grafana-dashboard-securekubeops-pipeline.yaml
  }
}

if (-not $SkipRuntimeSecurity) {
  if (-not $SkipHelmRepoUpdate) {
    Invoke-Step "Adding and updating Aqua Security Helm repository" {
      helm repo add aqua https://aquasecurity.github.io/helm-charts/ --force-update
      helm repo update
    }
  }

  Invoke-Step "Installing or updating Trivy Operator" {
    kubectl apply -f k8s/runtime-security/trivy-operator/namespace.yaml
    helm upgrade --install trivy-operator aqua/trivy-operator `
      --namespace runtime-security `
      --version 0.32.1 `
      -f k8s/runtime-security/trivy-operator/values.yaml
    kubectl apply --server-side -f k8s/monitoring/dashboards/grafana-dashboard-trivy-operator.yaml
  }
}

if ($IncludeWaf) {
  Ensure-Command "az"
  Invoke-Step "Deploying Azure WAF entry layer" {
    powershell -ExecutionPolicy Bypass -File .\azure-waf\scripts\deploy-waf.ps1
  }
} else {
  Write-Host ""
  Write-Host "WAF was not deployed. Use -IncludeWaf when you want to create the Azure WAF entry layer for tests."
}

Write-Host ""
Write-Host "Installation finished. Useful checks:"
Write-Host "kubectl get pods -A"
Write-Host "kubectl get svc -A"
Write-Host "kubectl get servicemonitor -n monitoring"
Write-Host "kubectl get vulnerabilityreports,configauditreports -A"
