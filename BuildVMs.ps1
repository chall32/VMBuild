#----------------------------------------------------------------------------------------------------
# BuildVMs.ps1
# Jase McCarty 6/5/2010 - http://www.jasemccarty.com/blog/?p=765
#
# v1.0  - 05 Sept 2012 - Chris Hall - Major Tweaking, VM recifiguration added, D:\ Drive creation
# v1.1  - 12 Sept 2012 - Chris Hall - E:\ , F:\ Drive creation, better variable handling
#
#----------------------------------------------------------------------------------------------------
# Change these to match your environment:

$VIServer = "192.168.0.10"
$VIUser   = "Administrator"
$VIPass   = "password"
$CSVFile  = "C:\Scripts\vms.csv"

# Change these to reset your customisation spec's networking: (yeah I know... use a temp custom spec... for a later script perhaps!)

$DefaultIP    = "192.168.0.100"
$DefaultMask  = "255.255.255.0"
$DefaultGW    = "192.168.0.1"
$DNSPrimary   = "192.168.0.1"
$DNSSecondary = "8.8.8.8"

#----------------------------------------------------------------------------------------------------
Set-PowerCLIConfiguration -InvalidCertificateAction:Ignore -Confirm:$False
Import-Module C:\Scripts\CheckForDVSIssueWithNoVDSSnapin.ps1

connect-VIserver -Server $VIServer -User $VIUser -Pass $VIPass
cls 

$vmlist = Import-CSV $CSVFile
 
foreach ($item in $vmlist) {

#---Variables pulled from the csvfile ---
    $basevm = $item.basevm
    $datastore = $item.datastore
    $vmhost = $item.vmhost
    $custspec = $item.custspec
    $vmname = $item.vmname
    $memoryGB = $item.memoryGB
    $cpu = $item.cpus
    $ipaddr = $item.ipaddress
    $subnet = $item.subnet
    $gateway = $item.gateway
    $pdns = $item.pdns
    $sdns = $item.sdns
    $portgrp = $item.portgroup
    $description = $item.description
    $datadrive1 = $item.DdrivesizeGB
    $datadrive2 = $item.EdrivesizeGB
    $datadrive3 = $item.FdrivesizeGB

    #--- Get the Specification and set the Nic Mapping ---
    Write-Host -ForegroundColor Green "*** Creating VM $vmname ***"
    Get-OSCustomizationSpec $custspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $ipaddr -SubnetMask $subnet -DefaultGateway $gateway -Dns $pdns,$sdns
 
    #--- Clone the BaseVM with the adjusted Customization Specification ---
    New-VM -Name $vmname -VM $basevm -Datastore $datastore -VMHost $vmhost | Set-VM -OSCustomizationSpec $custspec -Confirm:$false

    #--- Set CPU, RAM, Notes, Network Portgroup ---
    Write-Host -ForegroundColor Green "*** Reconfiguring VM $vmname ***" 
    $memory = ([int]$memoryGB * 1024)
    Get-VM -Name $vmname | Set-VM -MemoryMB $memory -NumCpu $cpu -Description $description -Confirm:$false | Get-NetworkAdapter | Set-NetworkAdapter -NetworkName $portgrp -Confirm:$false

     #--- Add Data Drives D:\ E:\ and F:\ ---
    If ($datadrive1) {
        Write-Host -ForegroundColor Green "*** Adding $datadrive1 GB D:\ to $vmname ***" 
        $datadrive1KB = ([int]$datadrive1 * 1024 * 1024)
        Get-VM -Name $vmname | New-HardDisk -CapacityKB $datadrive1KB -Persistence persistent }

    If ($datadrive2) {
        Write-Host -ForegroundColor Green "*** Adding $datadrive2 GB E:\ to $vmname ***" 
	$datadrive2KB = ([int]$datadrive2 * 1024 * 1024)
        Get-VM -Name $vmname | New-HardDisk -CapacityKB $datadrive2KB -Persistence persistent }

    If ($datadrive3) {
        Write-Host -ForegroundColor Green "*** Adding $datadrive3 GB F:\ to $vmname ***" 
	$datadrive3KB = ([int]$datadrive3 * 1024 * 1024)
        Get-VM -Name $vmname | New-HardDisk -CapacityKB $datadrive3KB -Persistence persistent }

    Else { 
	Write-Host -ForegroundColor Green "*** No Other Drives to add to $vmname ***"  } 
    Write-Host " "
}

#--- Remove the NicMapping from Customisation Spec ---
Write-Host -ForegroundColor Green "*** Job Done. All VMs Created. Re-setting Customisation Spec ***" 
Get-OSCustomizationSpec $custspec | Get-OSCustomizationNicMapping | Set-OSCustomizationNicMapping -IpMode UseStaticIp -IpAddress $DefaultIP -SubnetMask $DefaultMask -DefaultGateway $DefaultGW -Dns $DNSPrimary,$DNSSecondary

Disconnect-VIServer -Confirm:$False