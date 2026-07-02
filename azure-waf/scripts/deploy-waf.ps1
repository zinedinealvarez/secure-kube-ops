param(
  [string]$ResourceGroup = "rg-securekubeops-lab",
  [string]$AksName = "aks-securekubeops-lab",
  [string]$Location = "westeurope",
  [string]$BaseDomain = "securekubeops.local",
  [string]$WafPolicyName = "waf-securekubeops-detection",
  [string]$AlbSubnetName = "aks-appgateway",
  [string]$VnetName = "aks-vnet-10084315",
  [string]$LogAnalyticsWorkspaceName = "law-securekubeops-waf",
  [string]$DiagnosticSettingName = "diag-securekubeops-waf",
  [switch]$SkipDiagnostics,
  [switch]$SkipProviderRegistration,
  [switch]$SkipAlbAddonCheck
)

$ErrorActionPreference = "Stop"

function Get-RequiredValue {
  param(
    [string]$Name,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "Required value '$Name' is empty. Check the previous Azure/Kubernetes command output."
  }

  return $Value
}

function Ensure-ProviderRegistered {
  param([string]$Namespace)

  $state = az provider show --namespace $Namespace --query registrationState -o tsv 2>$null
  if ($state -eq "Registered") {
    Write-Host "Provider already registered: $Namespace"
    return
  }

  Write-Host "Registering provider: $Namespace"
  az provider register --namespace $Namespace --only-show-errors | Out-Null
}

function Ensure-FeatureRegistered {
  param(
    [string]$Namespace,
    [string]$Name
  )

  $state = az feature show --namespace $Namespace --name $Name --query "properties.state" -o tsv 2>$null
  if ($state -eq "Registered") {
    Write-Host "Preview feature already registered: $Name"
    return
  }

  Write-Host "Registering preview feature: $Name"
  az feature register --namespace $Namespace --name $Name --only-show-errors | Out-Null
  throw "Preview feature '$Name' is registering. Wait until it is 'Registered' and rerun this script."
}

function Ensure-RoleAssignment {
  param(
    [string]$PrincipalId,
    [string]$PrincipalType = "ServicePrincipal",
    [string]$Scope,
    [string]$Role
  )

  $existing = az role assignment list `
    --assignee $PrincipalId `
    --scope $Scope `
    --query "[?roleDefinitionName=='$Role'] | length(@)" `
    -o tsv

  if ([int]$existing -gt 0) {
    Write-Host "Role already assigned: '$Role'"
    return
  }

  Write-Host "Assigning role '$Role'"
  az role assignment create `
    --assignee-object-id $PrincipalId `
    --assignee-principal-type $PrincipalType `
    --scope $Scope `
    --role $Role `
    --only-show-errors | Out-Null
}

function Render-Template {
  param(
    [string]$TemplatePath,
    [string]$OutputPath,
    [hashtable]$Values
  )

  $content = Get-Content $TemplatePath -Raw
  foreach ($key in $Values.Keys) {
    $content = $content -replace [regex]::Escape($key), $Values[$key]
  }
  Set-Content -Path $OutputPath -Value $content
}

Write-Host "Deploying Azure WAF entry layer for AKS..."
Write-Host "AKS: $AksName"
Write-Host "Resource group: $ResourceGroup"

if (-not $SkipProviderRegistration) {
  Ensure-ProviderRegistered "Microsoft.ContainerService"
  Ensure-ProviderRegistered "Microsoft.Network"
  Ensure-ProviderRegistered "Microsoft.ServiceNetworking"
  Ensure-ProviderRegistered "Microsoft.Insights"
  Ensure-ProviderRegistered "Microsoft.OperationalInsights"
  Ensure-FeatureRegistered "Microsoft.ContainerService" "ManagedGatewayAPIPreview"
  Ensure-FeatureRegistered "Microsoft.ContainerService" "ApplicationLoadBalancerPreview"
}

if (-not $SkipAlbAddonCheck) {
  $gatewayClass = kubectl get gatewayclass azure-alb-external -o name 2>$null
  if ([string]::IsNullOrWhiteSpace($gatewayClass)) {
    Write-Host "ALB Controller/Gateway API add-on not found. Enabling it on AKS..."
    az aks update `
      --resource-group $ResourceGroup `
      --name $AksName `
      --enable-gateway-api `
      --enable-application-load-balancer `
      --only-show-errors | Out-Null
  } else {
    Write-Host "ALB Controller/Gateway API add-on already available."
  }
}

$NodeResourceGroup = az aks show `
  --resource-group $ResourceGroup `
  --name $AksName `
  --query nodeResourceGroup `
  -o tsv
$NodeResourceGroup = Get-RequiredValue "NodeResourceGroup" $NodeResourceGroup
Write-Host "Node resource group: $NodeResourceGroup"

$AlbSubnetId = az network vnet subnet show `
  --resource-group $NodeResourceGroup `
  --vnet-name $VnetName `
  --name $AlbSubnetName `
  --query id `
  -o tsv
$AlbSubnetId = Get-RequiredValue "AlbSubnetId" $AlbSubnetId
Write-Host "ALB subnet: $AlbSubnetId"

$IdentityName = "applicationloadbalancer-$AksName"
$AlbPrincipalId = az identity show `
  --resource-group $NodeResourceGroup `
  --name $IdentityName `
  --query principalId `
  -o tsv
$AlbPrincipalId = Get-RequiredValue "AlbPrincipalId" $AlbPrincipalId
Write-Host "ALB managed identity principal: $AlbPrincipalId"

$NodeResourceGroupId = az group show --name $NodeResourceGroup --query id -o tsv
$NodeResourceGroupId = Get-RequiredValue "NodeResourceGroupId" $NodeResourceGroupId

Ensure-RoleAssignment `
  -PrincipalId $AlbPrincipalId `
  -Scope $NodeResourceGroupId `
  -Role "AppGW for Containers Configuration Manager"

Ensure-RoleAssignment `
  -PrincipalId $AlbPrincipalId `
  -Scope $AlbSubnetId `
  -Role "Network Contributor"

Write-Host "Ensuring Azure WAF Policy exists and is enabled in Detection mode..."
$existingWafPolicy = az network application-gateway waf-policy show `
  --resource-group $ResourceGroup `
  --name $WafPolicyName `
  --query id `
  -o tsv 2>$null

if ([string]::IsNullOrWhiteSpace($existingWafPolicy)) {
  az network application-gateway waf-policy create `
    --resource-group $ResourceGroup `
    --name $WafPolicyName `
    --location $Location `
    --type Microsoft_DefaultRuleSet `
    --version 2.1 `
    --only-show-errors | Out-Null
}

az network application-gateway waf-policy policy-setting update `
  --resource-group $ResourceGroup `
  --policy-name $WafPolicyName `
  --mode Detection `
  --state Enabled `
  --only-show-errors | Out-Null

$WafPolicyId = az network application-gateway waf-policy show `
  --resource-group $ResourceGroup `
  --name $WafPolicyName `
  --query id `
  -o tsv
$WafPolicyId = Get-RequiredValue "WafPolicyId" $WafPolicyId
Write-Host "WAF policy: $WafPolicyId"

Ensure-RoleAssignment `
  -PrincipalId $AlbPrincipalId `
  -Scope $WafPolicyId `
  -Role "Contributor"

Write-Host "Rendering generated manifests from templates..."
Render-Template `
  -TemplatePath "azure-waf/manifests/application-load-balancer.template.yaml" `
  -OutputPath "azure-waf/manifests/application-load-balancer.yaml" `
  -Values @{ "<ALB_SUBNET_ID>" = $AlbSubnetId }

Render-Template `
  -TemplatePath "azure-waf/manifests/gateway-and-routes.template.yaml" `
  -OutputPath "azure-waf/manifests/gateway-and-routes.yaml" `
  -Values @{ "<BASE_DOMAIN>" = $BaseDomain }

Render-Template `
  -TemplatePath "azure-waf/manifests/waf-policy-association.template.yaml" `
  -OutputPath "azure-waf/manifests/waf-policy-association.yaml" `
  -Values @{ "<AZURE_WAF_POLICY_RESOURCE_ID>" = $WafPolicyId }

Write-Host "Applying Application Gateway for Containers, routes, health check and WAF association..."
kubectl apply -f azure-waf/manifests/application-load-balancer.yaml
kubectl apply -f azure-waf/manifests/gateway-and-routes.yaml
kubectl apply -f azure-waf/manifests/health-check-policy.yaml
kubectl apply -f azure-waf/manifests/waf-policy-association.yaml

Write-Host "Forcing WAF policy reconciliation..."
$Now = Get-Date -Format o
kubectl annotate webapplicationfirewallpolicy securekubeops-waf-policy `
  -n application `
  "securekubeops.io/reconcile=$Now" `
  --overwrite
kubectl annotate webapplicationfirewallpolicy juice-shop-waf-policy `
  -n vulnerable-lab `
  "securekubeops.io/reconcile=$Now" `
  --overwrite

if (-not $SkipDiagnostics) {
  Write-Host "Ensuring Log Analytics workspace and diagnostic settings..."

  $WorkspaceId = az monitor log-analytics workspace list `
    --resource-group $ResourceGroup `
    --query "[?name=='$LogAnalyticsWorkspaceName'].id | [0]" `
    -o tsv

  if ([string]::IsNullOrWhiteSpace($WorkspaceId)) {
    az monitor log-analytics workspace create `
      --resource-group $ResourceGroup `
      --workspace-name $LogAnalyticsWorkspaceName `
      --location $Location `
      --only-show-errors | Out-Null

    $WorkspaceId = az monitor log-analytics workspace show `
      --resource-group $ResourceGroup `
      --workspace-name $LogAnalyticsWorkspaceName `
      --query id `
      -o tsv
  }
  $WorkspaceId = Get-RequiredValue "WorkspaceId" $WorkspaceId

  $AlbResourceId = az resource list `
    --resource-group $NodeResourceGroup `
    --resource-type "Microsoft.ServiceNetworking/trafficControllers" `
    --query "[0].id" `
    -o tsv
  $AlbResourceId = Get-RequiredValue "AlbResourceId" $AlbResourceId

  $ExistingDiagnosticSetting = az monitor diagnostic-settings list `
    --resource $AlbResourceId `
    --query "[?name=='$DiagnosticSettingName'].id | [0]" `
    -o tsv 2>$null

  if ([string]::IsNullOrWhiteSpace($ExistingDiagnosticSetting)) {
    az monitor diagnostic-settings create `
      --name $DiagnosticSettingName `
      --resource $AlbResourceId `
      --workspace $WorkspaceId `
      --logs '[{"category":"TrafficControllerAccessLog","enabled":true},{"category":"TrafficControllerFirewallLog","enabled":true}]' `
      --metrics '[{"category":"AllMetrics","enabled":true}]' `
      --only-show-errors | Out-Null
  } else {
    Write-Host "Diagnostic setting already exists: $DiagnosticSettingName"
  }
}

Write-Host "Current status:"
kubectl get gateway -n alb-infra
kubectl get httproute -A
kubectl get healthcheckpolicy -A
kubectl get webapplicationfirewallpolicy -A

Write-Host "Gateway hostname:"
kubectl get gateway securekubeops-gateway -n alb-infra -o jsonpath="{.status.addresses[0].value}"
Write-Host ""
