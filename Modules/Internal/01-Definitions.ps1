function Get-RangerManifestSchemaVersion {
    '1.1.0-draft'
}

function Get-RangerCollectorDefinitions {
    [ordered]@{
        'topology-cluster' = [pscustomobject][ordered]@{
            Id                = 'topology-cluster'
            FunctionName      = 'Invoke-RangerTopologyClusterCollector'
            Class             = 'core'
            Covers            = @('topology', 'cluster')
            DomainPayloads    = @('clusterNode')
            RequiredTargets   = @('cluster')
            RequiredCredential = 'cluster'
        }
        'hardware' = [pscustomobject][ordered]@{
            Id                = 'hardware'
            FunctionName      = 'Invoke-RangerHardwareCollector'
            Class             = 'optional'
            Covers            = @('hardware', 'oem-integration')
            DomainPayloads    = @('hardware', 'oemIntegration')
            RequiredTargets   = @('bmc')
            RequiredCredential = 'bmc'
        }
        'storage-networking' = [pscustomobject][ordered]@{
            Id                = 'storage-networking'
            FunctionName      = 'Invoke-RangerStorageNetworkingCollector'
            Class             = 'core'
            Covers            = @('storage', 'networking')
            DomainPayloads    = @('storage', 'networking')
            RequiredTargets   = @('cluster')
            RequiredCredential = 'cluster'
        }
        'workload-identity-azure' = [pscustomobject][ordered]@{
            Id                = 'workload-identity-azure'
            FunctionName      = 'Invoke-RangerWorkloadIdentityAzureCollector'
            Class             = 'core'
            Covers            = @('virtual-machines', 'identity-security', 'azure-integration')
            DomainPayloads    = @('virtualMachines', 'identitySecurity', 'azureIntegration')
            RequiredTargets   = @('cluster')
            RequiredCredential = 'cluster'
        }
        'monitoring-observability' = [pscustomobject][ordered]@{
            Id                = 'monitoring-observability'
            FunctionName      = 'Invoke-RangerMonitoringCollector'
            Class             = 'core'
            Covers            = @('monitoring', 'observability')
            DomainPayloads    = @('monitoring')
            RequiredTargets   = @('azure')
            RequiredCredential = 'azure'
        }
        'management-performance' = [pscustomobject][ordered]@{
            Id                = 'management-performance'
            FunctionName      = 'Invoke-RangerManagementPerformanceCollector'
            Class             = 'core'
            Covers            = @('management-tools', 'performance')
            DomainPayloads    = @('managementTools', 'performance')
            RequiredTargets   = @('cluster')
            RequiredCredential = 'cluster'
        }
    }
}

function Get-RangerDomainAliases {
    [ordered]@{
        'cluster'              = 'cluster'
        'topology'             = 'topology'
        'hardware'             = 'hardware'
        'oem'                  = 'oem-integration'
        'oem-integration'      = 'oem-integration'
        'storage'              = 'storage'
        'network'              = 'networking'
        'networking'           = 'networking'
        'virtual-machines'     = 'virtual-machines'
        'vms'                  = 'virtual-machines'
        'identity'             = 'identity-security'
        'identity-security'    = 'identity-security'
        'azure'                = 'azure-integration'
        'azure-integration'    = 'azure-integration'
        'monitoring'           = 'monitoring'
        'observability'        = 'observability'
        'management-tools'     = 'management-tools'
        'performance'          = 'performance'
    }
}

function Get-RangerReservedDomainPayloads {
    [ordered]@{
        clusterNode = [ordered]@{
            cluster       = [ordered]@{}
            nodes         = @()
            quorum        = [ordered]@{}
            faultDomains  = @()
            networks      = @()
            roles         = @()
            csvSummary    = [ordered]@{}
            updatePosture = [ordered]@{}
            eventSummary  = @()
            healthSummary = [ordered]@{}
            nodeSummary   = [ordered]@{}
            faultDomainSummary = [ordered]@{}
            networkSummary = [ordered]@{}
        }
        hardware = [ordered]@{
            nodes   = @()
            summary = [ordered]@{}
            firmware = [ordered]@{}
            security = [ordered]@{}
        }
        storage = [ordered]@{
            pools         = @()
            physicalDisks = @()
            virtualDisks  = @()
            volumes       = @()
            csvs          = @()
            qos           = @()
            sofs          = @()
            replica       = @()
            summary       = [ordered]@{}
        }
        networking = [ordered]@{
            nodes           = @()
            clusterNetworks = @()
            adapters        = @()
            vSwitches       = @()
            hostVirtualNics = @()
            intents         = @()
            dns             = @()
            proxy           = @()
            firewall        = @()
            sdn             = @()
            switchConfig    = @()
            firewallConfig  = @()
            summary         = [ordered]@{}
        }
        virtualMachines = [ordered]@{
            inventory       = @()
            placement       = @()
            workloadFamilies = @()
            replication     = @()
            summary         = [ordered]@{}
        }
        identitySecurity = [ordered]@{
            nodes           = @()
            certificates    = @()
            posture         = @()
            localAdmins     = @()
            auditPolicy     = @()
            activeDirectory = @()
            keyVault        = @()
            summary         = [ordered]@{}
        }
        azureIntegration = [ordered]@{
            context           = [ordered]@{}
            resources         = @()
            services          = @()
            policy            = @()
            backup            = @()
            update            = @()
            cost              = @()
            resourceBridge    = @()
            customLocations   = @()
            extensions        = @()
            arcMachines       = @()
            siteRecovery      = @()
            resourceSummary   = [ordered]@{}
            resourceLocations = @()
            policySummary     = [ordered]@{}
            auth              = [ordered]@{}
        }
        monitoring = [ordered]@{
            telemetry = @()
            ama       = @()
            dcr       = @()
            dce       = @()
            insights  = @()
            alerts    = @()
            health    = @()
            updateManager = @()
            summary   = [ordered]@{}
        }
        managementTools = [ordered]@{
            tools  = @()
            agents = @()
            summary = [ordered]@{}
        }
        performance = [ordered]@{
            nodes      = @()
            compute    = @()
            storage    = @()
            networking = @()
            outliers   = @()
            events     = @()
            summary    = [ordered]@{}
        }
        oemIntegration = [ordered]@{
            endpoints         = @()
            managementPosture = @()
        }
    }
}

function Get-RangerReportTierDefinitions {
    @(
        [pscustomobject][ordered]@{ Name = 'executive';  Title = 'Executive Summary'; Audience = 'executive' }
        [pscustomobject][ordered]@{ Name = 'management'; Title = 'Management Summary'; Audience = 'management' }
        [pscustomobject][ordered]@{ Name = 'technical';  Title = 'Technical Deep Dive'; Audience = 'technical' }
    )
}

function Get-RangerDiagramDefinitions {
    @(
        [pscustomobject][ordered]@{ Name = 'physical-architecture'; Title = 'Physical Architecture'; Tier = 'baseline'; Required = @('clusterNode'); Audience = @('executive', 'management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'logical-network-topology'; Title = 'Logical Network Topology'; Tier = 'baseline'; Required = @('networking'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'storage-architecture'; Title = 'Storage Architecture'; Tier = 'baseline'; Required = @('storage'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'vm-placement-map'; Title = 'VM Placement Map'; Tier = 'baseline'; Required = @('virtualMachines'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'azure-arc-integration'; Title = 'Azure Arc Integration'; Tier = 'baseline'; Required = @('azureIntegration'); Audience = @('executive', 'management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'workload-services-map'; Title = 'Workload and Services Map'; Tier = 'baseline'; Required = @('virtualMachines', 'azureIntegration'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'topology-variant-map'; Title = 'Topology and Deployment Variant Map'; Tier = 'extended'; Required = @('clusterNode'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'identity-secret-flow'; Title = 'Identity, Trust, and Secret Flow'; Tier = 'extended'; Required = @('identitySecurity', 'azureIntegration'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'monitoring-telemetry-flow'; Title = 'Monitoring, Telemetry, and Alerting Flow'; Tier = 'extended'; Required = @('monitoring'); Audience = @('executive', 'management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'connectivity-dependency-map'; Title = 'Connectivity, Firewall, and Dependency Map'; Tier = 'extended'; Required = @('networking', 'azureIntegration'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'identity-access-surface'; Title = 'Identity and Access Surface Map'; Tier = 'extended'; Required = @('identitySecurity'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'monitoring-health-heatmap'; Title = 'Monitoring and Health Heatmap'; Tier = 'extended'; Required = @('monitoring', 'clusterNode'); Audience = @('executive', 'management') }
        [pscustomobject][ordered]@{ Name = 'oem-firmware-posture'; Title = 'OEM Hardware and Firmware Posture'; Tier = 'extended'; Required = @('hardware', 'oemIntegration'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'backup-recovery-map'; Title = 'Backup, Recovery, and Continuity Map'; Tier = 'extended'; Required = @('azureIntegration'); Audience = @('executive', 'management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'management-plane-tooling'; Title = 'Management Plane and Tooling Map'; Tier = 'extended'; Required = @('managementTools'); Audience = @('executive', 'management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'workload-family-placement'; Title = 'Workload Family Placement Map'; Tier = 'extended'; Required = @('virtualMachines'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'fabric-map'; Title = 'Rack-Aware Fabric Map'; Tier = 'extended'; Required = @('clusterNode', 'networking'); Audience = @('management', 'technical') }
        [pscustomobject][ordered]@{ Name = 'disconnected-control-plane'; Title = 'Disconnected Operations Control Plane Map'; Tier = 'extended'; Required = @('azureIntegration', 'identitySecurity'); Audience = @('management', 'technical') }
    )
}