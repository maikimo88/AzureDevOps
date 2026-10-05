# AVD Infrastructure as Code (Bicep & Azure DevOps)

Dit project automatiseert de uitrol van een complete Azure Virtual Desktop (AVD) omgeving met behulp van **Bicep** (Infrastructure as Code) en **Azure DevOps Pipelines**.

## 🏗️ Architectuur & Modulen

De architectuur is opgebouwd rondom een centrale orkestrator (`main.bicep`) op abonnementsniveau die automatisch de benodigde resources onderbrengt in de dedicated resourcegroep `rg-lab-devops-01`:

* **`main.bicep`**: Het hoofdscript (`targetScope = 'subscription'`) dat de Resource Group aanmaakt en alle onderliggende modules aanstuurt.
* **`vnet.bicep`**: Verantwoordelijk voor het netwerk, inclusief het Virtual Network en de interne subnets.
* **`avd.bicep`**: Bevat de componenten voor Azure Virtual Desktop, waaronder:
  * Host Pool (`avdpool-kraanlab-prod-02`)
  * Workspace (`vdow-klant-prod-02`)
  * Application Group (`vdag-klant-prod-desktop-02`)
  * Session Host Virtuele Machine (`biceps-avd-02`) inclusief de `AADLoginForWindows`-extensie voor naadloze Entra ID Join.
* **`storage.bicep`**: Maakt het Storage Account (`bicepfslogixprofiles`) en de bijbehorende File Share aan voor FSLogix-profielen.

## 🚀 CI/CD Pipeline & Automatisering

De automatisering loopt via een centrale pipeline gedefinieerd in `azure.pipelines.yml`. 
* **Triggers**: 
  * Automatische run bij een commit op de `main`-branch.
  * Voorbereid op een dagelijkse geplande uitvoering (`schedules` / cron) voor continue infrastructuur-enforcement en herstel.
* **Uitvoering**: Maakt gebruik van een Linux-agent (`ubuntu-latest`) die via de Azure CLI (`az deployment sub create`) de Bicep-implementatie start op basis van GitHub als single source of truth.
