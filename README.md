# AVD Infrastructure as Code (Bicep & Azure DevOps)

Dit project automatiseert de uitrol van een complete Azure Virtual Desktop (AVD) omgeving met behulp van **Bicep** (Infrastructure as Code) en **Azure DevOps Pipelines**.

## 🏗️ Architectuur & Modulen

De architectuur is opgebouwd rondom een centrale orkestrator (`main.bicep`) op abonnementsniveau die automatisch de benodigde resources onderbrengt in een dedicated resourcegroep:

* **`main.bicep`**: Het hoofdscript (`targetScope = 'subscription'`) dat de Resource Group aanmaakt en alle onderliggende modules aanstuurt.
* **`vnet.bicep`**: Verantwoordelijk voor het netwerk, inclusief het Virtual Network en de interne subnets.
* **`avd.bicep`**: Bevat de componenten voor Azure Virtual Desktop, waaronder:
  * Host Pool (`avdpool-kraanlab-prod-01`)
  * Workspace (`vdow-klant-prod-01`)
  * Application Group (`vdag-klant-prod-desktop`)
  * Session Host (`biceps-avd-01`) inclusief Entra ID Join en AVD-registratie-extensies.
* **`storage.bicep`**: Maakt het Storage Account (`bicepfslogixprofiles`) en de bijbehorende File Share aan voor FSLogix-profielen.

## 🚀 CI/CD Pipeline

De automatisering loopt via een enkele, centrale pipeline gedefinieerd in `azure.pipelines.yml`. 
* **Trigger**: Automatische run bij een commit op de `main`-branch.
* **Uitvoering**: Maakt gebruik van een opgeschaalde Linux-agent (`ubuntu-latest`) die via de Azure CLI (`az deployment sub create`) de Bicep-implementatie start.