param(
  [string]$ResourceGroup = "rg-securekubeops-lab",
  [string]$AksName = "aks-securekubeops-lab",
  [string]$WafPolicyName = "waf-securekubeops-detection",
  [string]$LogAnalyticsWorkspaceName = "law-securekubeops-waf",
  [string]$DiagnosticSettingName = "diag-securekubeops-waf",
  [switch]$DeleteGeneratedManifests,
  [switch]$DisableAlbAddon,
  [switch]$DeleteLogAnalyticsWorkspace
)

$ErrorActionPreference = "Continue"

function Remove-KubernetesManifestIfExists {
  param([string]$Path)

  if (Test-Path $Path) {
    kubectl delete -f $Path --ignore-not-found
  } else {
    Write-Host "Skipping missing manifest: $Path"
  }
}

function Remove-GeneratedManifestIfExists {
  param([string]$Path)

  if (Test-Path $Path) {
    Remove-Item -LiteralPath $Path -ErrorAction SilentlyContinue
  }
}

Write-Host "Cleaning Azure WAF entry layer for AKS..."
Write-Host "AKS: $AksName"
Write-Host "Resource group: $ResourceGroup"

$NodeResourceGroup = az aks show `
  --resource-group $ResourceGroup `
  --name $AksName `
  --query nodeResourceGroup `
  -o tsv 2>$null

if (-not [string]::IsNullOrWhiteSpace($NodeResourceGroup)) {
  $AlbResourceId = az resource list `
    --resource-group $NodeResourceGroup `
    --resource-type "Microsoft.ServiceNetworking/trafficControllers" `
    --query "[0].id" `
    -o tsv 2>$null

  if (-not [string]::IsNullOrWhiteSpace($AlbResourceId)) {
    Write-Host "Deleting diagnostic setting if it exists..."
    az monitor diagnostic-settings delete `
      --name $DiagnosticSettingName `
      --resource $AlbResourceId `
      --only-show-errors 2>$null
  }
}

Write-Host "Deleting Kubernetes WAF associations and routing resources..."
Remove-KubernetesManifestIfExists "azure-waf/manifests/waf-policy-association.yaml"
Remove-KubernetesManifestIfExists "azure-waf/manifests/health-check-policy.yaml"
Remove-KubernetesManifestIfExists "azure-waf/manifests/gateway-and-routes.yaml"
Remove-KubernetesManifestIfExists "azure-waf/manifests/application-load-balancer.yaml"

Write-Host "Waiting a few seconds for Azure to detach the WAF policy..."
Start-Sleep -Seconds 20

Write-Host "Deleting Azure WAF Policy if it exists..."
az network application-gateway waf-policy delete `
  --resource-group $ResourceGroup `
  --name $WafPolicyName `
  --yes `
  --only-show-errors 2>$null

if ($DeleteLogAnalyticsWorkspace) {
  Write-Host "Deleting Log Analytics workspace: $LogAnalyticsWorkspaceName"
  az monitor log-analytics workspace delete `
    --resource-group $ResourceGroup `
    --workspace-name $LogAnalyticsWorkspaceName `
    --yes `
    --force true `
    --only-show-errors
} else {
  Write-Host "Log Analytics workspace kept. Use -DeleteLogAnalyticsWorkspace to remove it too."
}

if ($DeleteGeneratedManifests) {
  Write-Host "Deleting generated manifests. Templates are kept."
  Remove-GeneratedManifestIfExists "azure-waf/manifests/application-load-balancer.yaml"
  Remove-GeneratedManifestIfExists "azure-waf/manifests/gateway-and-routes.yaml"
  Remove-GeneratedManifestIfExists "azure-waf/manifests/waf-policy-association.yaml"
}

if ($DisableAlbAddon) {
  Write-Host "Disabling ALB/Gateway API add-ons on AKS..."
  az aks update `
    --resource-group $ResourceGroup `
    --name $AksName `
    --disable-gateway-api `
    --disable-application-load-balancer
} else {
  Write-Host "ALB Controller add-on kept. Use -DisableAlbAddon only if you want to remove it from AKS."
}

Write-Host "Cleanup requested. Useful checks:"
Write-Host "kubectl get applicationloadbalancer,gateway,httproute,healthcheckpolicy,webapplicationfirewallpolicy -A"
Write-Host "az network application-gateway waf-policy list --resource-group $ResourceGroup -o table"
