param location string = resourceGroup().location
param vmName string = 'win-devbox'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string

// 1. Networking (VNet & Subnet)
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${vmName}-vnet'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.0.0.0/16'] }
    subnets: [{
        name: 'default'
        properties: { addressPrefix: '10.0.1.0/24' }
    }]
  }
}

// 2. Security (NSG for RDP)
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${vmName}-nsg'
  location: location
  properties: {
    securityRules: [{
        name: 'AllowRDP'
        properties: {
          priority: 1000
          access: 'Allow'
          direction: 'Inbound'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '3389'
          sourceAddressPrefix: '*' // Professional Tip: Change to your IP for SOC 2 compliance
          destinationAddressPrefix: '*'
        }
    }]
  }
}

// 3. The Windows VM with Managed Identity
resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  identity: { type: 'SystemAssigned' } // Enables the VM to talk to Key Vault without a password
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' } // Free-tier eligible SKU
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [{
          id: nic.id
      }]
    }
  }
}

// 4. Auto-Shutdown (Cost Governance)
resource autoShutdown 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: 'Enabled'
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: { time: '1900' } // 7:00 PM
    timeZoneId: 'UTC'
    targetResourceId: vm.id
  }
}

// NIC and Public IP resources omitted for brevity
