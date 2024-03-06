local SelectionService = game:GetService("Selection")
local InsertService = game:GetService("InsertService")
local toolbar: PluginToolbar = plugin:CreateToolbar("Sound Rolloff Visualisation")
local toggleButton: PluginToolbarButton = toolbar:CreateButton("Toggle", "Toggles on or off the rolloff visualisation", "rbxassetid://16644824331")
local workspaceChangeButton: PluginToolbarButton = toolbar:CreateButton("Connect to Workspace changes", "Toggles on or off the detection of currently playing audios in Workspacce or any that get created", "rbxassetid://16646716512")
toggleButton.ClickableWhenViewportHidden = false
workspaceChangeButton.ClickableWhenViewportHidden = false
if plugin:GetSetting("FIRST_LAUNCH") == nil then -- Inital console message
	warn("Sound Rolloff Visualisation plugin has been installed!\nCheckout the PLUGINS tab in your ribben for toggling and click on a Sound instance to preview the rolloff radius.")
	plugin:SetSetting("FIRST_LAUNCH", true)
end

-- // Init
local cachedVisual = InsertService:CreateMeshPartAsync("rbxassetid://16645138186", Enum.CollisionFidelity.Box, Enum.RenderFidelity.Precise)
cachedVisual.Name = "SoundRolloffVisualisationMesh"
cachedVisual.Material = Enum.Material.Neon
cachedVisual.Transparency = 0.85
cachedVisual.CastShadow = false
cachedVisual.CanCollide = false
cachedVisual.Anchored = true
cachedVisual.Locked = true

function createNewShape(): MeshPart
	return cachedVisual:Clone()
end
function resolvePosition(parented: Instance): Vector3
	local position: Vector3 = Vector3.new(0, 0, 0)

	if parented:IsA("Attachment") then
		return parented.WorldPosition
	end

	local success, output = pcall(function(...)
		return parented.Position
	end)
	if success then
		position = output
	end

	return position
end
function updateShape(visual: MeshPart, parented: Instance, value: number)
	visual.Size = Vector3.new(value, value, value)
	visual.Position = resolvePosition(parented)
end
function safeDestroy(instance: Instance)
	local success, output = pcall(function(...)
		instance:Destroy()
	end)
	if not success then
		warn("Sound Rolloff Visualisation: Error during discarding Sound Property Listener thread; issues may occur!\nOutput: ")
		warn(output)
	end
end
function safeDisconnect(thread: thread)
	local success, output = pcall(function(...)
		thread:Disconnect()
	end)
	if not success then
		warn("Sound Rolloff Visualisation: Error during discarding Sound Property Listener thread; issues may occur!\nOutput: ")
		warn(output)
	end
end

function findInstanceIn(providedTable, instance: Instance): boolean -- THIS SUCKS SO MUCH, I HATE IT
	for _, items in providedTable do
		if items[1] == instance then
			return true
		end
	end
	return false
end

local SelectionListener: thread
local previousSelection = {}
function createSelectionListener()
	toggleButton:SetActive(true)

	SelectionListener = SelectionService.SelectionChanged:Connect(function()
		local selecting = SelectionService:Get()
		local newSelection = {}

		for _, selection: Instance in selecting do
			if selection:IsA("Sound") then
				table.insert(newSelection, selection)
				if findInstanceIn(previousSelection, selection) then
					continue -- We are still selecting; We don't need to re-setup everything
				end

				local rolloffMaxShape = createNewShape()
				local rolloffMinShape = createNewShape()
				rolloffMaxShape.Color = Color3.fromRGB(239, 122, 54)
				rolloffMaxShape.Parent = game.Workspace.Terrain
				rolloffMinShape.Color = Color3.fromRGB(42, 42, 42)
				rolloffMinShape.Parent = game.Workspace.Terrain
				updateShape(rolloffMaxShape, selection.Parent, selection.RollOffMaxDistance)
				updateShape(rolloffMinShape, selection.Parent, selection.RollOffMinDistance)

				local rolloffMaxListener = selection:GetPropertyChangedSignal("RollOffMaxDistance"):Connect(function(...: any)
					updateShape(rolloffMaxShape, selection.Parent, selection.RollOffMaxDistance)
				end)
				local rolloffMinListener = selection:GetPropertyChangedSignal("RollOffMinDistance"):Connect(function(...: any)
					updateShape(rolloffMinShape, selection.Parent, selection.RollOffMinDistance)
				end)

				table.insert(previousSelection, { -- Add it to dict so we can keep track of it when we do a update!
					selection,
					rolloffMaxListener,
					rolloffMinListener,
					rolloffMaxShape,
					rolloffMinShape
				})
			end
		end

		-- Clean up previous
		for index, items in previousSelection do
			local sound = items[1]

			if table.find(newSelection, sound) == nil then
				safeDisconnect(items[2])
				safeDisconnect(items[3])
				safeDestroy(items[4])
				safeDestroy(items[5])
				table.remove(previousSelection, index)
			end
		end
	end)
end

-- // Main control area
if plugin:GetSetting("TOGGLE") then
	createSelectionListener()
end

toggleButton.Click:Connect(function() -- Toggling functionality
	local toggleSetting = plugin:GetSetting("TOGGLE") or false
	local newToggle = not toggleSetting
	plugin:SetSetting("TOGGLE", newToggle)

	if newToggle == false then
		toggleButton:SetActive(false)

		local success, output = pcall(function(...)
			SelectionListener:Disconnect()
		end)
		if not success then
			warn("Sound Rolloff Visualisation: Error during discarding Selection Listener thread; issues may occur!\nOutput: ")
			warn(output)
		end

		for index, items in previousSelection do
			local sound = items[1]

			safeDisconnect(items[2])
			safeDisconnect(items[3])
			safeDestroy(items[4])
			safeDestroy(items[5])
			items = nil
		end
	else
		createSelectionListener()
	end
end)
local toggleForChange = false
local ChangeListener: thread
workspaceChangeButton.Click:Connect(function()
	toggleForChange = not toggleForChange
	workspaceChangeButton:SetActive(toggleForChange)
	
	if toggleForChange then
		ChangeListener = game.Workspace.DescendantAdded:Connect(function(descendant: Instance)
			if descendant:IsA("Sound") then
				local rolloffMaxShape = createNewShape()
				local rolloffMinShape = createNewShape()
				rolloffMaxShape.Color = Color3.fromRGB(239, 122, 54)
				rolloffMaxShape.Parent = game.Workspace.Terrain
				rolloffMinShape.Color = Color3.fromRGB(42, 42, 42)
				rolloffMinShape.Parent = game.Workspace.Terrain
				updateShape(rolloffMaxShape, descendant.Parent, descendant.RollOffMaxDistance)
				updateShape(rolloffMinShape, descendant.Parent, descendant.RollOffMinDistance)

				local rolloffMaxListener = descendant:GetPropertyChangedSignal("RollOffMaxDistance"):Connect(function(...: any)
					updateShape(rolloffMaxShape, descendant.Parent, descendant.RollOffMaxDistance)
				end)
				local rolloffMinListener = descendant:GetPropertyChangedSignal("RollOffMinDistance"):Connect(function(...: any)
					updateShape(rolloffMinShape, descendant.Parent, descendant.RollOffMinDistance)
				end)
				
				descendant.Destroying:Once(function()
					rolloffMaxShape:Destroy()
					rolloffMinShape:Destroy()
					rolloffMaxListener:Disconnect()
					rolloffMinListener:Disconnect()
				end)
			end
		end)
	else
		local success, output = pcall(function(...)
			ChangeListener:Disconnect()
		end)
		if not success then
			warn("Sound Rolloff Visualisation: Error during discarding Workspace Changed Listener thread; issues may occur!\nOutput: ")
			warn(output)
		end
	end
end)
