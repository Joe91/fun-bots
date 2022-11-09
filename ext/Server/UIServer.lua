---@class FunBotUIServer
---@overload fun():FunBotUIServer
FunBotUIServer = class 'FunBotUIServer'

require('__shared/ArrayMap')
require('__shared/Config')

---@type Language
Language = require('__shared/Language')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
---@type SettingsManager
local m_SettingsManager = require('SettingsManager')
-- @type NodeEditor 
local m_NodeEditor = require('NodeEditor')

---@type BotManager
local BotManager = require('BotManager')
---@type BotSpawner
local BotSpawner = require('BotSpawner')
---@type WeaponList
local WeaponList = require('__shared/WeaponList')

function FunBotUIServer:__init()
	-- To-do: remove? Unused. 
	self.m_NavigaionPath = {}
	self.m_InPathMenu = false
	

	if Config.DisableUserInterface ~= true then
		NetEvents:Subscribe('UI_Request_Open', self, self._onUIRequestOpen)
		NetEvents:Subscribe('UI_Request_Save_Settings', self, self._onUIRequestSaveSettings)
		NetEvents:Subscribe('BotEditor', self, self._onBotEditorEvent)
		NetEvents:Subscribe('UI_Request_CommoRose_Show', self, self._onUIRequestCommonRoseShow)
	end
end

function FunBotUIServer:_onBotEditorEvent(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	-- Low permission for Comm-Screen. To-do: for all? 
	if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	local request = json.decode(p_Data)

	-- Reenter or hide Data-Menu?
	if request.action == 'data_menu' then
		if self.m_InPathMenu then
			request.action = 'hide_comm'
		elseif self.m_NavigaionPath[p_Player.onlineId] and #self.m_NavigaionPath[p_Player.onlineId] > 0 then
			-- goto last posiiton in menu
			request.action = self.m_NavigaionPath[p_Player.onlineId][#self.m_NavigaionPath[p_Player.onlineId]]
			self.m_InPathMenu = true
		end
	end

	-- Editor Data-Menu
	if request.action == 'data_menu' or request.action == 'back_to_data_menu' then
		if not Globals.IsConquest and not Globals.IsRush then
			ChatManager:SendMessage('This menu is not available in this gamemode.', p_Player)
			return
		end
		self.m_InPathMenu = true
		self.m_NavigaionPath[p_Player.onlineId] = {}
		-- Change Commo-rose. 
		local s_Left = {}
		if Globals.IsRush then
			s_Left = {
			    {
					Action = 'set_mcom',
					Label = Language:I18N('Add Mcom-Action'),
				}, {
					Action = 'loop_path',
					Label = Language:I18N('Overwrite: Loop-Path')
				}, {
					Action = 'invert_path',
					Label = Language:I18N('Overwrite: Reverse-Path')
				},{
					Action = 'remove_data',
					Label = Language:I18N('Remove Data')
				}
			}
		else
			s_Left = {
			    {
					Action = 'loop_path',
					Label = Language:I18N('Overwrite: Loop-Path')
				}, {
					Action = 'invert_path',
					Label = Language:I18N('Overwrite: Reverse-Path')
				},{
					Action = 'remove_data',
					Label = Language:I18N('Remove Data')
				}
			}
		end
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Right = {
				{
					Action = 'add_objective',
					Label = Language:I18N('Add Label / Objective')
				},{
					Action = 'remove_objective',
					Label = Language:I18N('Remove Label / Objective')
				}, {
					Action = 'vehicle_menu',
					Label = Language:I18N('Vehicles')
				}, {
					Action = 'remove_all_objectives',
					Label = Language:I18N('Remove all Labels / Objectives')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Paths') -- Or "Unselect". 
			},
			Left = s_Left,
			Bottom = {
				Action = 'close_comm',
				Label = Language:I18N('Exit'),
			}
		})	
		return
	elseif request.action == 'close_comm' then
		self.m_NavigaionPath[p_Player.onlineId] = {}
		self.m_InPathMenu = false
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'hide_comm' then
		self.m_InPathMenu = false
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'set_spawn_path' then
		m_NodeEditor:OnSetSpawnPath(p_Player)
		return
	elseif request.action == 'remove_all_objectives' then
		m_NodeEditor:OnRemoveAllObjectives(p_Player)
		return
	elseif request.action == 'remove_data' then
		m_NodeEditor:OnRemoveData(p_Player)
		return
	elseif request.action == 'loop_path' then
		m_NodeEditor:OnSetLoopMode(p_Player, {"true"})
		return
	elseif request.action == 'invert_path' then
		m_NodeEditor:OnSetLoopMode(p_Player, {"false"})
		return
	elseif request.action == 'set_mcom' then
		m_NodeEditor:OnAddMcom(p_Player)
		return
	elseif request.action == 'set_vehicle_path_type' then
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Right = {
				{
					Action = 'path_type_land',
					Label = Language:I18N('Land')
				}, {
					Action = 'path_type_water',
					Label = Language:I18N('Water')
				}, {
					Action = 'path_type_air',
					Label = Language:I18N('Air')
				}, {
					Action = 'path_type_clear',
					Label = Language:I18N('Clear Path-Type')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Path-Type') -- Or "Unselect". 
			},
			Left = {
			},
			Bottom = {
				Action = 'back_to_data_menu',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'vehicle_menu' then
		self.m_NavigaionPath[p_Player.onlineId][2] = nil
		self.m_NavigaionPath[p_Player.onlineId][1] = request.action
		
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'add_enter_vehicle',
					Label = Language:I18N('Enter Vehicle')
				}, {
					Action = 'add_exit_vehicle_passengers',
					Label = Language:I18N('Exit Vehicle Passengers')
				}, {
					Action = 'add_exit_vehicle_all',
					Label = Language:I18N('Exit Vehicle All')
				}, {
					Action = 'remove_data',
					Label = Language:I18N('Remove Vehicle Data')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Vehicle') -- Or "Unselect". 
			},
			Right = {
				-- vehicle Menu
				{
					Action = 'vehicle_objective',
					Label = Language:I18N('Add Vehicle')
				}, {
					Action = 'set_vehicle_path_type',
					Label = Language:I18N('Set Vehicle Path-Type')
				}, {
					Action = 'remove_all_objectives',
					Label = Language:I18N('Remove Vehicle')
				}
			},
			Bottom = {
				Action = 'back_to_data_menu',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'vehicle_objective' then
		self.m_NavigaionPath[p_Player.onlineId][5] = nil
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Right = {
				{
					Action = 'add_vehicle_tank',
					Label = Language:I18N('Add Tank')
				}, {
					Action = 'add_vehicle_chopper',
					Label = Language:I18N('Add Chopper')
				}, {
					Action = 'add_vehicle_plane',
					Label = Language:I18N('Add Plane')
				}, {
					Action = 'add_vehicle_other',
					Label = Language:I18N('Add Other Vehicle')
				}
		},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Vehicle') -- Or "Unselect". 
			},
			Left = {
				{
					Action = 'set_vehicle_spawn',
					Label = Language:I18N('Set Vehicle Spawn-Path')
				}
			},
			Bottom = {
				Action = 'vehicle_menu',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif string.find(request.action, 'add_vehicle_') ~= nil then
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action
		
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'team_us',
					Label = Language:I18N('US')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Team') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'team_ru',
					Label = Language:I18N('RU')
				}
			},
			Bottom = {
				Action = 'vehicle_objective',
				Label = Language:I18N('Back')
			}
		})
	elseif string.find(request.action, 'team_') ~= nil then
		self.m_NavigaionPath[p_Player.onlineId][5] = nil
		self.m_NavigaionPath[p_Player.onlineId][4] = request.action
		
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'index_vehcile_1',
					Label = Language:I18N('Vehicle 1')
				}, {
					Action = 'index_vehcile_2',
					Label = Language:I18N('Vehicle 2')
				}, {
					Action = 'index_vehcile_3',
					Label = Language:I18N('Vehicle 3')
				}, {
					Action = 'index_vehcile_4',
					Label = Language:I18N('Vehicle 4')
				}, {
					Action = 'index_vehcile_5',
					Label = Language:I18N('Vehicle 5')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Index') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'index_vehcile_6',
					Label = Language:I18N('Vehicle 6')
				}, {
					Action = 'index_vehcile_7',
					Label = Language:I18N('Vehicle 7')
				}, {
					Action = 'index_vehcile_8',
					Label = Language:I18N('Vehicle 8')
				}, {
					Action = 'index_vehcile_9',
					Label = Language:I18N('Vehicle 9')
				}, {
					Action = 'index_vehcile_10',
					Label = Language:I18N('Vehicle 10')
				}
			},
			Bottom = {
				Action = 'vehicle_objective',
				Label = Language:I18N('Back')
			}
		})
	elseif string.find(request.action, 'index_vehcile_') ~= nil then
		self.m_NavigaionPath[p_Player.onlineId][5] = request.action
		-- FILL THIS
		local s_Team = self.m_NavigaionPath[p_Player.onlineId][4]:split('_')[2]
		local s_VehicleType = self.m_NavigaionPath[p_Player.onlineId][3]:split('_')[3]
		local s_Index = request.action:split('_')[3]
		local s_ObjectiveData = {}
		table.insert(s_ObjectiveData, "vehicle")
		table.insert(s_ObjectiveData, s_VehicleType..s_Index)
		table.insert(s_ObjectiveData, s_Team)
		m_NodeEditor:OnAddObjective(p_Player, s_ObjectiveData);
		return
		
	elseif request.action == 'set_vehicle_spawn' then
		m_NodeEditor:OnSetVehicleSpawn(p_Player);
		return
	elseif request.action == 'add_enter_vehicle' then
		m_NodeEditor:OnAddVehicle(p_Player)
		return
	elseif request.action == 'add_exit_vehicle_passengers' then
		m_NodeEditor:OnExitVehicle(p_Player, {"true"})
		return
	elseif request.action == 'add_exit_vehicle_all' then
		m_NodeEditor:OnExitVehicle(p_Player,  {"false"})
		return

	elseif request.action == 'add_objective' or request.action == 'remove_objective' then
		--NetEvents:SendTo('UI_Toggle_DataMenu', p_Player, true)
		-- Change Commo-rose. 
		self.m_NavigaionPath[p_Player.onlineId][2] = nil
		self.m_NavigaionPath[p_Player.onlineId][1] = request.action
		local s_Center = {}
		if request.action == 'add_objective' then
			s_Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Add') 
			}
		else
			s_Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Remove')
			}
		end
		if Globals.IsRush then
			NetEvents:SendTo('UI_CommonRose', p_Player, {
				Top = {
					Action = 'not_implemented',
					Label = Language:I18N(''),
					Confirm = true
				},
				Right = {
					{
						Action = 'base_rush',
						Label = Language:I18N('Base')
					}, {
						Action = 'add_mcom',
						Label = Language:I18N('MCOM')
					}, {
						Action = 'add_mcom_interact',
						Label = Language:I18N('MCOM Interact')
					}
				},
				Center = s_Center,
				Left = {
					{
						Action = 'set_spawn_path',
						Label = Language:I18N('Set Spawn-Path')
					}
				},
				Bottom = {
					Action = 'back_to_data_menu',
					Label = Language:I18N('Back')
				}
			})
			return
		else -- Conquest
			NetEvents:SendTo('UI_CommonRose', p_Player, {
				Top = {
					Action = 'not_implemented',
					Label = Language:I18N(''),
					Confirm = true
				},
				Right = {
					{
						Action = 'base_us',
						Label = Language:I18N('Base US')
					}, {
						Action = 'base_ru',
						Label = Language:I18N('Base RU')
					}, {
						Action = 'capture_point',
						Label = Language:I18N('Capture Point')
					}
				},
				Center = s_Center,
				Left = {
					{
						Action = 'set_spawn_path',
						Label = Language:I18N('Set Spawn-Path')
					}
				},
				Bottom = {
					Action = 'back_to_data_menu',
					Label = Language:I18N('Back')
				}
			})
			return
		end
	elseif request.action == 'add_mcom' then
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action

		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'mcom_1',
					Label = Language:I18N('MCOM 1')
				}, {
					Action = 'mcom_2',
					Label = Language:I18N('MCOM 2')
				}, {
					Action = 'mcom_3',
					Label = Language:I18N('MCOM 3')
				}, {
					Action = 'mcom_4',
					Label = Language:I18N('MCOM 4')
				}, {
					Action = 'mcom_5',
					Label = Language:I18N('MCOM 5')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('MCOM') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'mcom_6',
					Label = Language:I18N('MCOM 6')
				}, {
					Action = 'mcom_7',
					Label = Language:I18N('MCOM 7')
				}, {
					Action = 'mcom_8',
					Label = Language:I18N('MCOM 8')
				}, {
					Action = 'mcom_9',
					Label = Language:I18N('MCOM 9')
				}, {
					Action = 'mcom_10',
					Label = Language:I18N('MCOM 10')
				}
			},
			Bottom = {
				Action = 'add_objective',
				Label = Language:I18N('Back')
			}
		})
		return

	elseif request.action == 'add_mcom_interact' then
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action

		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'mcom_inter_1',
					Label = Language:I18N('MCOM INTERACT 1')
				}, {
					Action = 'mcom_inter_2',
					Label = Language:I18N('MCOM INTERACT 2')
				}, {
					Action = 'mcom_inter_3',
					Label = Language:I18N('MCOM INTERACT 3')
				}, {
					Action = 'mcom_inter_4',
					Label = Language:I18N('MCOM INTERACT 4')
				}, {
					Action = 'mcom_inter_5',
					Label = Language:I18N('MCOM INTERACT 5')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('MCOM') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'mcom_inter_6',
					Label = Language:I18N('MCOM INTERACT 6')
				}, {
					Action = 'mcom_inter_7',
					Label = Language:I18N('MCOM INTERACT 7')
				}, {
					Action = 'mcom_inter_8',
					Label = Language:I18N('MCOM INTERACT 8')
				}, {
					Action = 'mcom_inter_9',
					Label = Language:I18N('MCOM INTERACT 9')
				}, {
					Action = 'mcom_inter_10',
					Label = Language:I18N('MCOM INTERACT 10')
				}
			},
			Bottom = {
				Action = 'add_objective',
				Label = Language:I18N('Back')
			}
		})
		return

		
	elseif request.action == 'base_us' or  request.action == 'base_ru' or request.action == 'base_rush' then

		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action
		if Globals.IsRush then
			-- Add index here
			NetEvents:SendTo('UI_CommonRose', p_Player, {
				Top = {
					Action = 'not_implemented',
					Label = Language:I18N(''),
					Confirm = true
				},
				Left = {
					{
						Action = 'base_ru_1',
						Label = Language:I18N('base ru stage 1')
					}, {
						Action = 'base_ru_2',
						Label = Language:I18N('base ru stage 2')
					}, {
						Action = 'base_ru_3',
						Label = Language:I18N('base ru stage 3')
					}, {
						Action = 'base_ru_4',
						Label = Language:I18N('base ru stage 4')
					}, {
						Action = 'base_ru_5',
						Label = Language:I18N('base ru stage 5')
					}
				},
				Center = {
					Action = 'not_implemented',
					Label = Language:I18N('Base') -- Or "Unselect". 
				},
				Right = {
					{
						Action = 'base_us_1',
						Label = Language:I18N('base us stage 1')
					}, {
						Action = 'base_us_2',
						Label = Language:I18N('base us stage 2')
					}, {
						Action = 'base_us_3',
						Label = Language:I18N('base us stage 3')
					}, {
						Action = 'base_us_4',
						Label = Language:I18N('base us stage 4')
					}, {
						Action = 'base_us_5',
						Label = Language:I18N('base us stage 5')
					}
				},
				Bottom = {
					Action = 'add_objective',
					Label = Language:I18N('Back')
				}
			})
		else
			local s_BaseParts = request.action:split("_")
			if self.m_NavigaionPath[p_Player.onlineId][1] == "remove_objective" then
				m_NodeEditor:OnRemoveObjective(p_Player, s_BaseParts)
			else
				m_NodeEditor:OnAddObjective(p_Player, s_BaseParts)
			end
		end
		
		return
	elseif string.find(request.action, 'path_type_') ~= nil then
		local s_Type = request.action:split('_')[3]
		m_NodeEditor:OnAddVehiclePath(p_Player, {s_Type})
	elseif string.find(request.action, 'mcom_') ~= nil then
		local s_Data = request.action:split('_')
		local s_McomString = "mcom "..s_Data[2]
		if #s_Data == 3 then
			s_McomString = s_McomString.." interact"
		end
		if self.m_NavigaionPath[p_Player.onlineId][1] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, s_McomString:split(' '))
		else
			m_NodeEditor:OnAddObjective(p_Player, s_McomString:split(' '))
		end
		return
	elseif string.find(request.action, 'base_') ~= nil then
		local s_Data = request.action:split('_')
		if self.m_NavigaionPath[p_Player.onlineId][1] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, s_Data)
		else
			m_NodeEditor:OnAddObjective(p_Player, s_Data)
		end
		return
	elseif string.find(request.action, 'objective_') ~= nil then
		local s_Objective = request.action:split('_')[2]
		if self.m_NavigaionPath[p_Player.onlineId][1] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, {s_Objective})
		else
			m_NodeEditor:OnAddObjective(p_Player, {s_Objective})
		end
		return
	elseif request.action == 'capture_point' then

		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'objective_a',
					Label = Language:I18N('A')
				}, {
					Action = 'objective_b',
					Label = Language:I18N('B')
				}, {
					Action = 'objective_c',
					Label = Language:I18N('C')
				}, {
					Action = 'objective_d',
					Label = Language:I18N('D')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Objective') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'objective_e',
					Label = Language:I18N('E')
				}, {
					Action = 'objective_f',
					Label = Language:I18N('F')
				}, {
					Action = 'objective_g',
					Label = Language:I18N('G')
				}, {
					Action = 'objective_h',
					Label = Language:I18N('H')
				}
			},
			Bottom = {
				Action = 'add_objective',
				Label = Language:I18N('Back')
			}
		})	
		return

	-- Comm Screen. 
	elseif request.action == 'exit_vehicle' then
		BotManager:ExitVehicle(p_Player)
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'drop_ammo' then
		BotManager:Deploy(p_Player, "ammo")
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'drop_medkit' then
		BotManager:Deploy(p_Player, "medkit")
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'enter_vehicle' then
		BotManager:EnterVehicle(p_Player)
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'repair_vehicle' then
		BotManager:RepairVehicle(p_Player)
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'attack_objective' then
		-- Change Commo-rose. 
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'attack_a',
					Label = Language:I18N('A')
				}, {
					Action = 'attack_b',
					Label = Language:I18N('B')
				}, {
					Action = 'attack_c',
					Label = Language:I18N('C')
				}, {
					Action = 'attack_d',
					Label = Language:I18N('D')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Attack') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'attack_e',
					Label = Language:I18N('E')
				}, {
					Action = 'attack_f',
					Label = Language:I18N('F')
				}, {
					Action = 'attack_g',
					Label = Language:I18N('G')
				}, {
					Action = 'attack_h',
					Label = Language:I18N('H')
				}
			},
			Bottom = {
				Action = 'back_to_comm',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'defend_objective' then
		NetEvents:SendTo('UI_CommonRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'defend_a',
					Label = Language:I18N('A')
				}, {
					Action = 'defend_b',
					Label = Language:I18N('B')
				}, {
					Action = 'defend_c',
					Label = Language:I18N('C')
				}, {
					Action = 'defend_d',
					Label = Language:I18N('D')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Defend') -- Or "Unselect". 
			},
			Right = {
				{
					Action = 'defend_e',
					Label = Language:I18N('E')
				}, {
					Action = 'defend_f',
					Label = Language:I18N('F')
				}, {
					Action = 'defend_g',
					Label = Language:I18N('G')
				}, {
					Action = 'defend_h',
					Label = Language:I18N('H')
				}
			},
			Bottom = {
				Action = 'back_to_comm',
				Label = Language:I18N('Back'),
			}
		})
		return
	elseif string.find(request.action, 'attack_') ~= nil then
		local s_Objective = request.action:split('_')[2]
		BotManager:Attack(p_Player, s_Objective)
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif string.find(request.action, "defend_") ~= nil then
		local s_Objective = request.action:split('_')[2]
		BotManager:Attack(p_Player, s_Objective)
		NetEvents:SendTo('UI_CommonRose', p_Player, "false")
		return
	elseif request.action == 'back_to_comm' then
		self:_onUIRequestCommonRoseShow(p_Player)
		return
	end

	-- General Commands. 
	if PermissionManager:HasPermission(p_Player, 'UserInterface.BotEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	-- Settings. 
	if request.action == 'request_settings' then
		if Config.Language == nil then
			Config.Language = 'en_US'
		end

		-- request.opened 
		NetEvents:SendTo('UI_Settings', p_Player, Config)
	-- Bots. 
	elseif request.action == 'bot_spawn_default' then
		local amount = tonumber(request.value)
		local team = p_Player.teamId
		Globals.SpawnMode = "manual"

		if team == TeamId.Team1 then
			BotSpawner:SpawnWayBots(p_Player, amount, true, 0, 0, TeamId.Team2)
		else
			BotSpawner:SpawnWayBots(p_Player, amount, true, 0, 0, TeamId.Team1)
		end
	elseif request.action == 'bot_spawn_friend' then
		local amount = tonumber(request.value)
		Globals.SpawnMode = "manual"
		BotSpawner:SpawnWayBots(p_Player, amount, true, 0, 0, p_Player.teamId)
	elseif request.action == 'bot_spawn_path' then -- To-do: what's the difference? Make a function to spawn bots on a fixed way instead? 
		local amount = 1
		local indexOnPath = tonumber(request.pointindex) or 1
		local index = tonumber(request.value)
		Globals.SpawnMode = "manual"
		local s_TeamId = p_Player.teamId + 1

		if s_TeamId > Globals.NrOfTeams then
			s_TeamId = s_TeamId - Globals.NrOfTeams
		end

		BotSpawner:SpawnWayBots(p_Player, amount, false, index, indexOnPath, s_TeamId)
	elseif request.action == 'bot_kick_all' then
		Globals.SpawnMode = "manual"
		BotManager:DestroyAll()
	elseif request.action == 'bot_kick_team' then
		Globals.SpawnMode = "manual"
		local teamNumber = tonumber(request.value)

		if teamNumber == 1 then
			BotManager:DestroyAll(nil, TeamId.Team1)
		elseif teamNumber == 2 then
			BotManager:DestroyAll(nil, TeamId.Team2)
		end
	elseif request.action == 'bot_kill_all' then
		Globals.SpawnMode = "manual"
		BotManager:KillAll()
	elseif request.action == 'bot_respawn' then -- Toggle this function. 
		local respawning = not Globals.RespawnWayBots
		Globals.RespawnWayBots = respawning
		BotManager:SetOptionForAll('respawn', respawning)

		if respawning then
			ChatManager:Yell(Language:I18N('Bot respawn activated!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bot respawn deactivated!', request.action), 2.5)
		end
	elseif request.action == 'bot_attack' then -- Toggle this function. 
		local attack = not Globals.AttackWayBots
		Globals.AttackWayBots = attack
		BotManager:SetOptionForAll('shoot', attack)

		if attack then
			ChatManager:Yell(Language:I18N('Bots will attack!', request.action), 2.5)
		else
			ChatManager:Yell(Language:I18N('Bots will not attack!', request.action), 2.5)
		end
	-- Trace. 
	elseif request.action == 'trace_start' then
		m_NodeEditor:StartTrace(p_Player)
	-- NetEvents:SendToLocal('ClientNodeEditor:StartTrace', p_Player) 
	elseif request.action == 'trace_end' then
		m_NodeEditor:EndTrace(p_Player)
	-- NetEvents:SendToLocal('ClientNodeEditor:EndTrace', p_Player) 
	elseif request.action == 'trace_save' then
		local s_Index = tonumber(request.value)
		m_NodeEditor:SaveTrace(p_Player, s_Index)
	-- NetEvents:SendToLocal('ClientNodeEditor:SaveTrace', p_Player, s_Index) 
	elseif request.action == 'trace_clear' then
		m_NodeEditor:ClearTrace(p_Player)
	-- NetEvents:SendToLocal('ClientNodeEditor:ClearTrace', p_Player) 
	elseif request.action == 'trace_reset_all' then
		m_NodeCollection:Clear()
		NetEvents:BroadcastLocal('NodeCollection:Clear')
	elseif request.action == 'waypoints_server_load' then
		m_NodeCollection:Load()
	elseif request.action == 'waypoints_server_save' then
		m_NodeCollection:Save()
	elseif request.action == 'waypoints_show_spawns' then
		Config.DrawSpawnPoints = not Config.DrawSpawnPoints
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
	elseif request.action == 'waypoints_show_lines' then
		Config.DrawWaypointLines = not Config.DrawWaypointLines
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
	elseif request.action == 'waypoints_show_labels' then
		Config.DrawWaypointIDs = not Config.DrawWaypointIDs
		NetEvents:SendToLocal('WriteClientSettings', p_Player, Config, false)
	-- Waypoints-Editor 
	elseif request.action == 'request_waypoints_editor' then
		m_NodeEditor:OnOpenEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, true)
	elseif request.action == 'disable_waypoint_editor' then
		m_NodeEditor:OnCloseEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Disable', p_Player)
	elseif request.action == 'hide_waypoints_editor' then
		m_NodeEditor:OnCloseEditor(p_Player)
		NetEvents:SendTo('UI_Waypoints_Editor', p_Player, false)
	else
		ChatManager:Yell(Language:I18N('%s is currently not implemented', request.action), 2.5)
	end
end

function FunBotUIServer:_onUIRequestSaveSettings(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting to save settings.')
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface.Settings') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	local request = json.decode(p_Data)

	self:_writeSettings(p_Player, request)
end

function FunBotUIServer:_onUIRequestCommonRoseShow(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if not Config.AllowCommForAll and PermissionManager:HasPermission(p_Player, 'Comm') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting show CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', p_Player, {
		Top = {
			Action = 'not_implemented',
			Label = Language:I18N(''),
		},
		Left = {
			{
				Action = 'exit_vehicle',
				Label = Language:I18N('Exit Vehicle')
			}, {
				Action = 'enter_vehicle',
				Label = Language:I18N('Enter Vehicle')
			}, {
				Action = 'drop_ammo',
				Label = Language:I18N('Drop Ammo')
			}, {
				Action = 'drop_medkit',
				Label = Language:I18N('Drop Medkit')
			}
		},
		Center = {
			Action = 'not_implemented',
			Label = Language:I18N('Commands') -- Or "Unselect". 
		},
		Right = {
			{
				Action = 'attack_objective',
				Label = Language:I18N('Attack Objective')
			}, {
				Action = 'defend_objective',
				Label = Language:I18N('Defend Objective'),
			}, {
				Action = 'repair_vehicle',
				Label = Language:I18N('Repair Vehicle')
			}, {
				Action = 'not_implemented',
				Label = Language:I18N('')
			}
		},
		Bottom = {
			Action = 'not_implemented',
			Label = Language:I18N(''),
		}
	})
end

function FunBotUIServer:_onUIRequestCommonRoseHide(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface.WaypointEditor') == false then
		ChatManager:SendMessage('You have no permissions for this action.', p_Player)
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting hide CommonRose.')
	end

	NetEvents:SendTo('UI_CommonRose', p_Player, 'false')
end

function FunBotUIServer:_onUIRequestOpen(p_Player, p_Data)
	if Config.DisableUserInterface == true then
		return
	end

	if Debug.Server.UI then
		print(p_Player.name .. ' requesting open Bot-Editor.')
	end

	if PermissionManager:HasPermission(p_Player, 'UserInterface') then
		if Debug.Server.UI then
			print('Open Bot-Editor for ' .. p_Player.name .. '.')
		end

		NetEvents:SendTo('UI_Toggle', p_Player)
		NetEvents:SendTo('UI_Show_Toolbar', p_Player, 'true')
	else
		ChatManager:SendMessage('You have no permissions to open the UI', p_Player)
	end
end

function FunBotUIServer:_writeSettings(p_Player, p_Request)
	if Config.DisableUserInterface == true then
		return
	end

	local temporary = false
	local updateBotTeamAndNumber = false
	local updateWeaponSets = false
	local resetSkill = false
	local calcYawPerFrame = false
	local updateLanguage = false
	local updateMaxBots = false
	local batched = true

	if p_Request.subaction ~= nil then
		temporary = (p_Request.subaction == 'temp')
	end

	for _, l_Item in pairs(SettingsDefinition.Elements) do
		-- Validate requests. 
		if p_Request[l_Item.Name] ~= nil then
			local s_Changed = false
			local s_Value = nil
			local s_Valid = false

			if l_Item.Type == Type.Enum then
				-- Convert value back. 
				for l_Key, l_Value in pairs(l_Item.Reference) do
					if l_Key == p_Request[l_Item.Name] and l_Key ~= "Count" then
						s_Value = l_Value
						s_Valid = true

						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end

						break
					end
				end
			elseif l_Item.Type == Type.List then
				for _, l_Value in pairs(l_Item.Reference) do
					if l_Value == p_Request[l_Item.Name] then
						s_Value = l_Value
						s_Valid = true

						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end

						break
					end
				end
			elseif l_Item.Type == Type.DynamicList then
				local s_Reference = _G[l_Item.Reference]

				for _, l_Value in pairs(s_Reference) do
					if l_Value == p_Request[l_Item.Name] then
						s_Value = l_Value
						s_Valid = true
						if s_Value ~= Config[l_Item.Name] then
							s_Changed = true
						end
						break
					end
				end
			elseif l_Item.Type == Type.Integer or l_Item.Type == Type.Float then
				s_Value = tonumber(p_Request[l_Item.Name])
				---@type Range
				local s_Reference = l_Item.Reference

				if s_Reference:IsValid(s_Value) then
					s_Valid = true
					if math.abs(s_Value - Config[l_Item.Name]) > 0.001 then
						s_Changed = true
					end
				end
			elseif l_Item.Type == Type.Boolean then
				s_Value = p_Request[l_Item.Name] == true
				s_Valid = true

				if s_Value ~= Config[l_Item.Name] then
					s_Changed = true
				end
			end

			-- Update with value or with current Config. Update is needed to not lose Config Values. 
			if s_Valid then
				m_SettingsManager:Update(l_Item.Name, s_Value, temporary, batched)
			else
				m_SettingsManager:Update(l_Item.Name, Config[l_Item.Name], temporary, batched)
			end

			-- Check for update flags. 
			if s_Changed then
				if l_Item.UpdateFlag == UpdateFlag.WeaponSets then
					updateWeaponSets = true
				elseif l_Item.UpdateFlag == UpdateFlag.Skill then
					resetSkill = true
				elseif l_Item.UpdateFlag == UpdateFlag.YawPerSec then
					calcYawPerFrame = true
				elseif l_Item.UpdateFlag == UpdateFlag.AmountAndTeam then
					updateBotTeamAndNumber = true
				elseif l_Item.UpdateFlag == UpdateFlag.Language then
					updateLanguage = true
				elseif l_Item.UpdateFlag == UpdateFlag.MaxBots then
					updateMaxBots = true
				end
			end
		end
	end

	-- Language of UI. 
	if updateLanguage then
		Language:loadLanguage(Config.Language)
		NetEvents:SendTo('UI_Change_Language', p_Player, Config.Language)
	end

	-- Call batched process. 
	if batched then
		Database:ExecuteBatch()
	end

	if temporary then
		ChatManager:Yell(Language:I18N('Settings has been saved temporarily'), 2.5)
	else
		ChatManager:Yell(Language:I18N('Settings has been saved'), 2.5)
	end

	-- Update Weapons if needed. 
	if updateWeaponSets then
		WeaponList:UpdateWeaponList()
	end

	if resetSkill then
		BotManager:ResetSkills()
	end

	if calcYawPerFrame then
		Globals.YawPerFrame = BotManager:CalcYawPerFrame()
	end

	if updateMaxBots then
		g_FunBotServer:SetMaxBotsPerTeam(Globals.GameMode)
	end

	NetEvents:BroadcastLocal('WriteClientSettings', Config, updateWeaponSets)

	if updateBotTeamAndNumber then
		Globals.SpawnMode = Config.SpawnMode
		BotSpawner:UpdateBotAmountAndTeam()
	end

	-- To-do: create Error Array and don't hide if it has values. 
	NetEvents:SendTo('UI_Settings', p_Player, false)
end

if g_FunBotUIServer == nil then
	---@type FunBotUIServer
	g_FunBotUIServer = FunBotUIServer()
end

return g_FunBotUIServer
