<#
.SYNOPSIS
Launches a GUI application for selecting and running PowerShell scripts.

.DESCRIPTION
This script creates a graphical user interface (GUI) using XAML and Windows Forms, allowing users to select and launch PowerShell scripts. The configuration for the scripts and their organizational structure is loaded from a JSON configuration file. The GUI offers a tabbed interface with buttons corresponding to individual scripts, and it provides feedback on the status of the scripts (e.g., whether they exist or not).

.PARAMETER jsonconfig
Path to the JSON configuration file specifying scripts and their organization. If unspecified, it defaults to the config.json file located in the same directory as the script.

.EXAMPLE
.\GUIScriptRunner.ps1 -jsonconfig "C:\Path\To\Config.json"
This example launches the GUI using a specified JSON configuration file.
#>

param (
    [string]$jsonconfig = "$PSScriptRoot\config.json"#"config.json"
)

# Load assemblies
Add-Type -AssemblyName PresentationFramework,System.Windows.Forms

# XAML definition
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PowerShell Script Launcher" ResizeMode="CanResizeWithGrip" SizeToContent="WidthAndHeight">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TabControl Name="tabControl" Grid.Row="1" Margin="10"/>
        <StatusBar Name="statusBar" Grid.Row="2">
			<StatusBarItem>
				<TextBlock Name="statusText" Text="Please select a script to launch."/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
	<Window.Resources>
		<Style TargetType="{x:Type Button}" x:Key="CustomButtonStyle">
			<Setter Property="Background" Value="LightGray"/>
			<Setter Property="BorderBrush" Value="Gray"/>
			<Setter Property="Foreground" Value="Black"/>
			<Setter Property="Template">
				<Setter.Value>
					<ControlTemplate TargetType="{x:Type Button}">
						<Border Name="border" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" Background="{TemplateBinding Background}">
							<ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" Margin="{TemplateBinding Padding}" VerticalAlignment="{TemplateBinding VerticalContentAlignment}" SnapsToDevicePixels="{TemplateBinding SnapsToDevicePixels}"/>
						</Border>
						<ControlTemplate.Triggers>
							<Trigger Property="IsPressed" Value="True">
								<Setter Property="Background" Value="#B0B0B0" TargetName="border"/>
							</Trigger>
							<Trigger Property="IsMouseOver" Value="True">
								<Setter Property="Background" Value="Yellow" TargetName="border"/>
							</Trigger>
						</ControlTemplate.Triggers>
					</ControlTemplate>
				</Setter.Value>
			</Setter>
		</Style>
	</Window.Resources>
</Window>
"@

### This removed stackpanel used to display the username, password, and modern auth parts of the gui.
### You can uncomment this and move it back to the XAML area above just after </Grid.RowDefinitions>
#
#        <StackPanel Orientation="Horizontal" Margin="10">
#            <Label Content="Username:"/>
#            <TextBox Name="UsernameTextBox" Width="120" Margin="5,0,10,0"/>
#            <Label Content="Password:"/>
#            <PasswordBox Name="PasswordTextBox" Width="120" Margin="5,0,10,0"/>
#            <TextBox Name="PasswordAsteriskTextBox" Width="120" Margin="5,0,10,0" Visibility="Collapsed"/>
#            <CheckBox Name="ModernAuthCheckBox" Content="Use Modern Auth" Margin="5,0,10,0" VerticalAlignment="Center"/>
#        </StackPanel>


### Load JSON configuration
if (Test-Path $jsonconfig) {
    try {
        $config = Get-Content -Path $jsonconfig -Raw | ConvertFrom-Json
    } catch {
        Write-Host "Invalid JSON configuration file specified: $jsonconfig. Loading default config.json file."
        $config = Get-Content -Path "config.json" -Raw | ConvertFrom-Json
    }
} else {
    Write-Host "Cannot find the configuration file specified: $jsonconfig. Loading default config.json file."
    $config = Get-Content -Path "config.json" -Raw | ConvertFrom-Json
}

### Create the GUI
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# Get elements by name
$tabControl = $window.FindName("tabControl")
#$usernameTextBox = $window.FindName("UsernameTextBox")
#$passwordTextBox = $window.FindName("PasswordTextBox")
#$modernAuthCheckBox = $window.FindName("ModernAuthCheckBox")
$statusText = $window.FindName("statusText")

# Create tabs and buttons from JSON configuration
foreach ($tab in $config.Tabs) {
    $tabItem = [System.Windows.Controls.TabItem]::new()
    $tabItem.Header = $tab.Name
    $grid = [System.Windows.Controls.Grid]::new()

    # Add 3 columns to the grid
    for ($i = 0; $i -lt 3; $i++) {
        $col = New-Object System.Windows.Controls.ColumnDefinition
        $grid.ColumnDefinitions.Add($col)
    }

    $stackPanel = [System.Windows.Controls.StackPanel]::new()
    $stackPanel.Name = "stackPanel_$($tab.Name -replace ' ', '_' -replace '-', '_')"
    $stackPanel.Orientation = "Vertical"

    $buttonsWithGroup = $tab.Buttons | ForEach-Object {
        if ([string]::IsNullOrEmpty($_.Group)) {
            $group = 'General Scripts'
        } else {
            $group = $_.Group
        }

        $newButton = New-Object -TypeName psobject -Property @{
            Content = $_.Content
            ScriptPath = $_.ScriptPath
            ToolTip = $_.ToolTip
            Group = $group
        }
        ,$newButton
    }

    $buttonGroups = $buttonsWithGroup | Group-Object -Property 'Group' | Sort-Object -Property Name

    $columnCounter = 0
    $rowCounter = 0

    foreach ($buttonGroup in $buttonGroups) {
        $groupBox = New-Object System.Windows.Controls.GroupBox
        $groupBox.Header = $buttonGroup.Name

        $groupStackPanel = [System.Windows.Controls.StackPanel]::new()
        $groupStackPanel.Orientation = "Vertical"

        $sortedButtons = $buttonGroup.Group | Sort-Object -Property Content

        foreach ($button in $sortedButtons) {
            $btn = [System.Windows.Controls.Button]::new()
            $btn.Width = 200 # Fixed width to accommodate 32 characters
            $btn.HorizontalAlignment = "Left"
            $btn.HorizontalContentAlignment = "Left"
            $btn.Padding = "5,0,5,2"
			$btn.Style = $window.FindResource("CustomButtonStyle")

            $textBlock = New-Object System.Windows.Controls.TextBlock
            $textBlock.Text = $button.Content
            $textBlock.TextWrapping = [System.Windows.TextWrapping]::Wrap
            $textBlock.MaxWidth = 200 # Set the maximum width in pixels according to your preference

            $btn.Content = $textBlock
            $btn.Margin = "7,5,7,5"
            $btn.ToolTip = $button.ToolTip
            $btn.Tag = @{
                ScriptPath = $button.ScriptPath
            }
			# Check if script file exists
			if (-not (Test-Path $button.ScriptPath)) {
				$btn.Background = [System.Windows.Media.Brushes]::LightPink
            }

			$btn.Add_Click({
				$scriptPath = $_.Source.Tag.ScriptPath
				if (Test-Path $scriptPath) {
					Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
				} else {
					[System.Windows.MessageBox]::Show("The script file cannot be found at the configured location: `n`n  $scriptPath", "File Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
				}
			})

            $btn.Add_MouseEnter({
                $scriptPath = $_.Source.Tag.ScriptPath
				if (-not (Test-Path $scriptPath)) {
					$statusText.Foreground = [System.Windows.Media.Brushes]::Red
                    $statusText.Text = "ERROR: Script not found. Please verify that the file exists at " + $scriptPath
                } else {
					$statusText.Foreground = [System.Windows.Media.Brushes]::Black
                    $statusText.Text = "Click to run " + $_.Source.Tag.ScriptPath
                }
            })

			$btn.Add_MouseLeave({
				$statusText.Foreground = [System.Windows.Media.Brushes]::Black
				$statusText.Text = "Please select a script to launch."
			})

            $null = $groupStackPanel.Children.Add($btn)
		}
		$groupBox.Content = $groupStackPanel

        # Set the position of the groupBox in the grid
        [System.Windows.Controls.Grid]::SetColumn($groupBox, $columnCounter)
        [System.Windows.Controls.Grid]::SetRow($groupBox, $rowCounter)

        # Add a new row to the grid if it's the first groupBox
        if ($rowCounter -eq 0 -and $columnCounter -eq 0) {
            $row = New-Object System.Windows.Controls.RowDefinition
            $grid.RowDefinitions.Add($row)
        }

        [void]$grid.Children.Add($groupBox)

        $columnCounter++
        if ($columnCounter -eq 3) {
            $columnCounter = 0
            $rowCounter++

            # Add a new row to the grid
            $row = New-Object System.Windows.Controls.RowDefinition
            $grid.RowDefinitions.Add($row)
        }
    }

        # Add blank groups to fill empty columns
    while ($columnCounter -lt 3) {
        $blankGroupBox = New-Object System.Windows.Controls.GroupBox
        $blankGroupBox.Header = " "
        $blankGroupBox.Content = [System.Windows.Controls.StackPanel]::new()
        $blankGroupBox.Width = 200 + 19 # Set the width to match the width of the other group columns (200 + button margin)

        # Set the position of the groupBox in the grid
        [System.Windows.Controls.Grid]::SetColumn($blankGroupBox, $columnCounter)
        [System.Windows.Controls.Grid]::SetRow($blankGroupBox, $rowCounter)

        [void]$grid.Children.Add($blankGroupBox)
        $columnCounter++
    }

    $tabItem.Content = $grid
    [void]$tabControl.Items.Add($tabItem)
}

# Show the GUI
$null = $window.ShowDialog()