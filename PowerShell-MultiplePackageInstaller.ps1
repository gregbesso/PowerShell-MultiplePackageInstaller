#Requires -Version 3.0



# variables
# specify the domain controller to connect to...
$global:mipDomainController = 'YourDomainControllerName'

# the URL to the SharePoint site you'll be storing the information in...
$global:mipSPWeb = 'https://sharepoint/sites/PSMANAGE'

# the SharePoint server you'll connect to to read/write when needed. Just the hostname or FQDN, not the URL...
$global:mipSharePointServer = 'YourSharePointServerName'

# the user you want to assign the tasks to...
$global:mipAssignTo = 'domain\UserTaskAssignedTo' 

# by default inherits global logo from launch pad, but you can change that if you wanted to...
If ($global:lpLogoURL) {
    $global:mipLogoURL = $global:lpLogoURL #Powershell-Logo.png
    $global:mipLogoURLH = $global:lpLogoURLH
    $global:mipLogoURLW = $global:lpLogoURLW

    # setting padding between objects in the form...
    $global:mipPaddingH = $global:lpPaddingH
    $global:mipPaddingV = $global:lpPaddingV
} Else { 
    # if using this script within LaunchPad, you can remove this entire ELSE section :-)
    # add assembly used later on for image formatting...
    Add-Type -AssemblyName System.Drawing
    $global:mipLogoURL = "\\gbesso-w12r2\SHARE\Style\Powershell-Logo-01.png"

    # set max dimension you want to see on the image you choose to use...
    $maxDimension = 250

    # getting the dimensions of the image file...
    $png = New-Object System.Drawing.Bitmap $global:mipLogoURL
    $global:mipLogoURLH = $png.Height
    $global:mipLogoURLW = $png.Width

    # get resized dimensions for the image if needed...
    if (($global:mipLogoURLH -gt $maxDimension) -Or ($global:mipLogoURLW -gt $maxDimension)) {
        if ($global:mipLogoURLW -gt $global:mipLogoURLH) {
            $ratio = $maxDimension/$global:mipLogoURLW
            $global:mipLogoURLW = $maxDimension
            $global:mipLogoURLH = $global:mipLogoURLH * $ratio
        }
        if ($global:mipLogoURLH -gt $maxDimension) {
            $ratio = $maxDimension/$global:mipLogoURLH
            $global:mipLogoURLW = $global:mipLogoURLW * $ratio
            $global:mipLogoURLH = $global:mipLogoURLH * $ratio
        }

    }
    # setting padding between objects in the form...
    $global:mipPaddingH = 30
    $global:mipPaddingV = 15
}


# function that gets a list of the current install packages from SharePoint...
function Get-PSManagePackages() {
<# 
.SYNOPSIS 
Gets information from a SharePoint list of available installation packages
.DESCRIPTION 
Each package has a name, a UNC path to an installation executable, a name for add/remove programs for verification.
.PARAMETER spWeb
The URL of the SharePoint workspace that the PSMANAGE lists are stored in.
.EXAMPLE 
Get-PSManagePackages -spWeb 'https://sharepoint/sites/psmanage'
#>
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string]$spWeb
    )
    #create a new session and load the SharePoint plugins...
    $sessionSharePoint = New-PSSession -ComputerName $global:mipSharePointServer
    Invoke-Command -Session $sessionSharePoint -ScriptBlock {

        Param ($spWeb)

        Add-PSSnapin Microsoft.SharePoint.PowerShell

        #send the list information over to the session and get the spare DIDs
        $sourceWebURL = "$spWeb"
        $sourceListName = "PSMANAGE-PACKAGES"
        $spSourceWeb = Get-SPWeb "$sourceWebURL"
        $spSourceList = $spSourceWeb.Lists[$sourceListName]
        $spSourceItems = $spSourceList.Items        
        $output = @() 
        
        ForEach ($package in $spSourceItems) {
            $PackageID = $package['ID']
            $PackageName = $package['PackageName']
            $PackageInstaller = $package['PackageInstaller']
            $PackageDetails = $package['PackageDetails']
            $PackageVerify = $package['PackageVerify']

            #$TaskPackage = $TaskPackage.Replace("1;#","")           

            $object1 = [pscustomobject]@{
                pID = $PackageID
                PackageName = $PackageName;
                PackageInstaller = $PackageInstaller;
                PackageDetails = $PackageDetails; 
                PackageVerify = $PackageVerify;                    
            }
            $output += $object1 

        }
    } -ArgumentList $spWeb
    $spSourceItems = Invoke-Command -Session $sessionSharePoint -ScriptBlock { $output }

    #close session once information is obtained... 
    $sessionSharePoint | Remove-PSSession

    #give output
    Return $spSourceItems
}

# function that gets a list of the computers that are using the PSMANAGE phone home scripts...
function Get-PSManageActiveWindowsComputers() {
<# 
.SYNOPSIS 
Gets a list of Windows computers that are currently phoning home to the PSMANAGE SharePoint list.
.DESCRIPTION 
Computers that phone home are eligible to receive tasks to install software packages.
.PARAMETER spWeb
The URL of the SharePoint workspace that the PSMANAGE lists are stored in.
.EXAMPLE 
Get-PSManageActiveWindowsComputers -spWeb 'https://sharepoint/sites/psmanage'
#>
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [string]$spWeb
    )
    #create a new session and load the SharePoint plugins...
    $sessionSharePoint = New-PSSession -ComputerName $global:mipSharePointServer
    Invoke-Command -Session $sessionSharePoint -ScriptBlock {

        Param ($spWeb)

        Add-PSSnapin Microsoft.SharePoint.PowerShell

        #send the list information over to the session and get the spare DIDs
        $sourceWebURL = "$spWeb"
        $sourceListName = "PSMANAGE-COMPUTERS"
        $spSourceWeb = Get-SPWeb "$sourceWebURL"
        $spSourceList = $spSourceWeb.Lists[$sourceListName]
        $spSourceItems = $spSourceList.Items        
        $output = @() 
        
        ForEach ($computer in $spSourceItems) {

            $PSLastPhoneHome = $computer['PSLastPhoneHome']

            If ($PSLastPhoneHome.Length -gt 0) {
                $ComputerID = $computer['ID']
                $computerTitle = $computer['Title']
                $computerOS = $computer['AD-OperatingSystem']
                $computerUser = $computer['CS-UserName']                      

                $object1 = [pscustomobject]@{
                    cID = $computerID;
                    ComputerTitle = $computerTitle;
                    ComputerOS = $computerOS;
                    ComputerUser = $computerUser;                    
                }
                $output += $object1 
            }

        }
    } -ArgumentList $spWeb
    $spSourceItems = Invoke-Command -Session $sessionSharePoint -ScriptBlock { $output }

    #close session once information is obtained...
    $sessionSharePoint | Remove-PSSession

    #give output
    Return $spSourceItems
}

# creates new tasks in SharePoint for the chosen package and computers...
function New-MultiplePackageInstallerTasks() {
<# 
.SYNOPSIS 
Publishes new tasks to the list that computers will read later to receive their install tasks.
.DESCRIPTION 
Computers read the tasks list to find out what software package(s) they should install.
.PARAMETER sendArray
The PS object of the install task(s) being created.
.PARAMETER chosenPackageID
The unique list item ID for the package being installed for each task.
.PARAMETER chosenTaskName
A label to put on the new task(s) being created.
.PARAMETER spWeb
The URL of the SharePoint workspace that the PSMANAGE lists are stored in.
.PARAMETER spServer
The hostname of the SharePoint server that the remote PS session is made to.
.PARAMETER spAssignTo
The domain user that the task is assigned to, only for label purposes.
.EXAMPLE 
Get-PSManageActiveWindowsComputers -spWeb 'https://sharepoint/sites/psmanage'
#>
    Param (
        [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)]
        [object]$sendArray,
        [object]$chosenComputerID,
        [string]$chosenTaskName,
        [string]$spWeb,
        [string]$spServer,
        [string]$spAssignTo 
    )

    BEGIN{}
    PROCESS{
        Try {
            #connect to sharepoint and send data over...
            $sessionSharePoint = New-PSSession -ComputerName $spServer
            Invoke-Command -Session $sessionSharePoint -ScriptBlock {
                # get input from function calling remote session
                Param ($sendArray, $chosenComputerID, $chosenTaskName, $spWeb, $spAssignTo)

                Add-PSSnapin Microsoft.SharePoint.PowerShell
                #send the list information over to the session
                $rightNow = Get-Date
                $spWeb = Get-SPWeb $spWeb
                $spListName = 'PSMANAGE-TASKS'

                #get list info...
                $path = $spWeb.Url.Trim()
                $spList = $spWeb.Lists["$spListName"]
                $spFieldType = [Microsoft.SharePoint.SPFieldType]::Text
                $PSComputerName = ""

                #start loop for array...
                $sendArray | ForEach {
                    Try {
                        #create the new task...
                        $thisPackage = $_.ChosenPackageName
                        $thisPID = $_.pID
                        $newItem = $spList.AddItem()

                        $newItem["TaskName"] = "$chosenTaskName"
                        $newItem["TaskPackage"] = $thisPID
                        $newItem["PSComputerName"] = $chosenComputerID
                        $newItem["TaskStatus"] = "Not Started"

                        $assignTo = $spWeb.EnsureUser("$spAssignTo")
                        $newItem["TaskAssignedTo"] = $assignTo

                        $newItem.Update()

                        #once done creating the task...
                        $spList.Update()

                    } Catch{}
                #END loop for array
                }
            } -ArgumentList $sendArray, $chosenComputerID, $chosenTaskName, $spWeb, $spAssignTo

            #close session once done...
            $sessionSharePoint | Remove-PSSession
        } Catch {
            Write-Warning "Error occurred: $_.Exception.Message"
        }
    }
    End {}
}

# creates the GUI form that lets all the stuff happen...
function Get-MassInstallPackageForm() {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") 
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 


    $script:preferredDC = "$global:mipDomainController"

    $getPackages = Get-PSManagePackages -spWeb $global:mipSPWeb
    $getPackages = $getPackages | Sort-Object PackageName
    $getPackages = $getPackages | Select-Object -Property PackageName, pID

    $getComputers = Get-PSManageActiveWindowsComputers -spWeb $global:mipSPWeb
    $getComputers = $getComputers | Sort-Object ComputerTitle
    $getComputers = $getComputers | Select-Object -Property ComputerTitle,ComputerOS,ComputerUser,cID


    $objForm = New-Object System.Windows.Forms.Form 
    $objForm.Text = "Multiple Package Installer Form"
    $objForm.AutoSize = $True
    $objForm.StartPosition = "CenterScreen"
    $objForm.BackColor = "#333333"
    $objForm.ForeColor = "#ffffff"
    $Font = New-Object System.Drawing.Font("Lucida Sans Console",10,[System.Drawing.FontStyle]::Regular)
    $objForm.Font = $Font
    $itemY = 0

    $objForm.KeyPreview = $True
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") {$x=$objTextBox.Text;$objForm.Close()}})
    $objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") {$objForm.Close()}})

    # add an image
    $pictureBox = new-object Windows.Forms.PictureBox
    $pictureBox.Width =  $global:mipLogoURLW
    $pictureBox.Height =  $global:mipLogoURLH
    $pictureBox.ImageLocation = $global:mipLogoURL
    $pictureBox.SizeMode = 4
    $pictureBox.Location = New-Object Drawing.Point 10,10
    $objForm.controls.add($pictureBox)

    # add the GUI title
    $objLabelTitle = New-Object System.Windows.Forms.Label
    $objLabelTitle.Location = New-Object System.Drawing.Size(($pictureBox.Left+$pictureBox.Width+$global:mipPaddingH),$global:mipPaddingV)
    $objLabelTitle.AutoSize = $True 
    $objLabelTitle.Text = "Multiple Package Installer Form"
    $Font = New-Object System.Drawing.Font("Lucida Sans Console",12,[System.Drawing.FontStyle]::Bold)
    $objLabelTitle.Font = $Font
    $objForm.Controls.Add($objLabelTitle) 


   

    # label for selecting a package...
    $objLabelA = New-Object System.Windows.Forms.Label
    $objLabelA.Location = New-Object System.Drawing.Size($objLabelTitle.Left,($objLabelTitle.Bottom+($global:mipPaddingV*2)))
    $objLabelA.AutoSize = $True 
    $objLabelA.Text = "Select a computer to deploy to..."
    $objForm.Controls.Add($objLabelA) 


    # drop-down list for selecting a package...
    $DropDownComputer = new-object System.Windows.Forms.ComboBox
    $DropDownComputer.Location = New-Object System.Drawing.Size($objLabelA.Left,($objLabelA.Bottom+($global:mipPaddingV/2)))
    $DropDownComputer.Size = new-object System.Drawing.Size(270,20)
    $DropDownComputer.Height = 120
   
    $getComputers | ForEach-Object {
        $addThis = $_.ComputerTitle
        [void] $DropDownComputer.Items.Add($addThis)
    }
    $objForm.Controls.Add($DropDownComputer)  




    # field for new task name...

    $labelNewTask = New-Object System.Windows.Forms.Label
    $labelNewTask.Location = New-Object System.Drawing.Size(($DropDownComputer.Right+$global:mipPaddingH),$objLabelA.Top)
    $labelNewTask.AutoSize = $True 
    $labelNewTask.Text = "Enter a name for your install task, such as 'new computer for john donut'"
    $objForm.Controls.Add($labelNewTask)

    $txtNewTask = New-Object System.Windows.Forms.TextBox 
    $txtNewTask.Location = New-Object System.Drawing.Size($labelNewTask.Left,$DropDownComputer.Top) 
    $txtNewTask.Size = New-Object System.Drawing.Size(270,20) 
    $objForm.Controls.Add($txtNewTask) 



    # label and datagrid box to list the available computers for installing packages to...
    $labelSelectPackages = New-Object System.Windows.Forms.Label
    $b1 = $pictureBox.Bottom
    $b2 = $DropDownComputer.Bottom
    If ($b1 -gt $b2) {$b3 = $b1} Else { $b3 = $b2} #get bottom of whichever item is lower, to align the grid positioning...
    $labelSelectPackages.Location = New-Object System.Drawing.Size($pictureBox.Left,($b3+($global:mipPaddingV*2))) 
    $labelSelectPackages.AutoSize = $True 
    $labelSelectPackages.Text = "Control-Click or Shift-Click the package(s) you want to deploy... "
    $objForm.Controls.Add($labelSelectPackages)
    
    $dataGrid1 = New-Object System.Windows.Forms.DataGridView
    $dataGrid1.Width = 400
    $dataGrid1.Height = 300
    $dataGrid1.DefaultCellStyle.ForeColor = "#000000"
    $dataGrid1.Name = "dataGrid1"
    $array = New-Object System.Collections.ArrayList
    $array.AddRange($getPackages)
    $dataGrid1.DataSource = $array
    $dataGrid1.ReadOnly = $True
    $dataGrid1.Location = New-Object System.Drawing.Size($labelSelectPackages.Left,($labelSelectPackages.Bottom+($global:mipPaddingV/2)))
    $dataGrid1.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::AllCells
    $objForm.Controls.Add($dataGrid1)


    # label and datagrid box to show chosen computers
    $labelSelectedPackages = New-Object System.Windows.Forms.Label
    $labelSelectedPackages.Location = New-Object System.Drawing.Size(($dataGrid1.Right+($global:mipPaddingH*2)),($labelSelectPackages.Top))
    $labelSelectedPackages.AutoSize = $True 
    $labelSelectedPackages.Text = "List of selected packages..."
    $objForm.Controls.Add($labelSelectedPackages)
    
    $dataGrid2 = New-Object System.Windows.Forms.DataGridView
    $dataGrid2.Width = 400
    $dataGrid2.Height = 300
    $dataGrid2.DefaultCellStyle.ForeColor = "#000000"
    $dataGrid2.Name = "dataGrid2"
    $dataGrid2.ReadOnly = $True
    $array = New-Object System.Collections.ArrayList    
    $dataGrid2.Location = New-Object System.Drawing.Size(($dataGrid1.Right+($global:mipPaddingH*2)),($dataGrid1.Top))
    $dataGrid2.AutoSizeColumnsMode = [System.Windows.Forms.DataGridViewAutoSizeColumnsMode]::AllCells
    $objForm.Controls.Add($dataGrid2)


    # buttons to continue/cancel on the form...
    $AddButton = New-Object System.Windows.Forms.Button
    $AddButton.Location = New-Object System.Drawing.Size(($dataGrid1.Left),($dataGrid1.Bottom+$global:mipPaddingV))
    $AddButton.Size = New-Object System.Drawing.Size(100,23)
    $AddButton.Text = "Update List"
    $AddButton.Enabled = $True
    $AddButton.Add_Click({       
        $listUpdate = @()
        $selectedItems = $dataGrid1.SelectedRows

        $thisCount = $selectedItems.Count
        If ($thisCount -gt 0) {
            $selectedItems | ForEach-Object {
                $thisIndex = $_.Index
                $thisPackageName = $dataGrid1.Rows[$thisIndex].Cells[0].Value
                $thisPackageID = $dataGrid1.Rows[$thisIndex].Cells[1].Value

                $object2 = [pscustomobject]@{
                    ChosenPackageName = $thisPackageName;
                    pID = $thisPackageID;                  
                }
                $listUpdate += $object2  
            }

            $listUpdate = $listUpdate | Sort-Object ChosenPackageName
            $array2 = New-Object System.Collections.ArrayList
            $array2.AddRange(@($listUpdate))
            $dataGrid2.DataSource = $array2
        }        
    })
    $objForm.Controls.Add($AddButton)


    $ProcessButton = New-Object System.Windows.Forms.Button
    $ProcessButton.Location = New-Object System.Drawing.Size(($AddButton.Right+$global:mipPaddingH),$AddButton.Top)
    $ProcessButton.Size = New-Object System.Drawing.Size(100,23)
    $ProcessButton.Text = "Create Tasks"
    $ProcessButton.Add_Click({        
        $chosenComputer = $DropDownComputer.SelectedItem

        $getComputers | ForEach-Object {
            $compareThis = $_.ComputerTitle
            If ($compareThis -eq $chosenComputer) {
                $chosenComputerID = $_.cID
            }
        }

        $chosenTaskName = $txtNewTask.Text
        $chosenPackages = $dataGrid2.Rows

        If ($chosenComputer.Length -lt 1) {
            $objLabelResults.Text = 'Select a computer to deploy to!'
        } ElseIf ($chosenPackages.Count -lt 1) {
            $objLabelResults.Text = 'Choose packages to deploy!'
        } ElseIf ($chosenTaskName.Length -lt 3) {
            $objLabelResults.Text = 'Enter a name for your install task!'
        } Else {
            $objLabelResults.Text = 'Standby, your tasks are being created...'
            $sendArray = @()
            $chosenPackages | ForEach-Object {
                $thisIndex = $_.Index
                $thisPackageName = $dataGrid2.Rows[$thisIndex].Cells[0].Value
                $thisPackageID = $dataGrid2.Rows[$thisIndex].Cells[1].Value

                $object1 = [pscustomobject]@{
                    ChosenPackageName = $thisPackageName; 
                    pID = $thisPackageID;                
                }
                $sendArray += $object1
            }

            # call the function to create the tasks once the data is all ready...
            New-MultiplePackageInstallerTasks -sendArray $sendArray -chosenComputerID $chosenComputerID -chosenTaskName $chosenTaskName -spWeb $global:mipSPWeb -spServer $global:mipSharePointServer -spAssignTo $global:mipAssignTo
            $objLabelResults.Text = 'OK your tasks have been created! Check the SharePoint list to see them :-)'
        }
    })
    $objForm.Controls.Add($ProcessButton)

    # cancel/exit button...
    $CancelButton = New-Object System.Windows.Forms.Button
    $CancelButton.Location = New-Object System.Drawing.Size(($ProcessButton.Right+$global:mipPaddingH),$AddButton.Top)
    $CancelButton.Size = New-Object System.Drawing.Size(100,23)
    $CancelButton.Text = "Exit"
    $CancelButton.Add_Click({
        #close any sessions that were opened, then close the form...
        Get-PSSession | Remove-PSSession
        $objForm.Close()
    })
    $objForm.Controls.Add($CancelButton)

    # display the results
    $objLabelResults = New-Object System.Windows.Forms.Label
    $objLabelResults.Location = New-Object System.Drawing.Size(($CancelButton.Right+$global:mipPaddingH),$AddButton.Top)
    $objLabelResults.AutoSize = $True 
    $objLabelResults.Text = ""
    $objForm.Controls.Add($objLabelResults) 
    $objForm.Topmost = $True

    $Icon = [system.drawing.icon]::ExtractAssociatedIcon($PSHOME + "\powershell.exe")
    $objForm.Icon = $Icon

    $objForm.Add_Shown({$objForm.Activate()})
    [void] $objForm.ShowDialog()
}

# bring up the GUI form that will get the process started...
Get-MassInstallPackageForm
