---@class FunBotUIPathMenu
---@overload fun():FunBotUIPathMenu
FunBotUIPathMenu = class 'FunBotUIPathMenu'

require('__shared/ArrayMap')
require('__shared/Config')

---@type Language
Language = require('__shared/Language')

---@type NodeCollection
local m_NodeCollection = require('NodeCollection')
-- @type NodeEditor
local m_NodeEditor = require('NodeEditor')

function FunBotUIPathMenu:__init()
	-- To-do: remove? Unused.
	self.m_NavigaionPath = {}
	self.m_InPathMenu = false

	if Config.DisableUserInterface ~= true then
		NetEvents:Subscribe('PathMenu:Request', self, self._OnPathMenuRequest)
		NetEvents:Subscribe('PathMenu:Open', self, self._OnPathMenuOpen)
		NetEvents:Subscribe('PathMenu:Hide', self, self._OnPathMenuHide)
		NetEvents:Subscribe('PathMenu:Unhide', self, self._OnPathMenuUnhide)
		NetEvents:Subscribe('PathMenu:Close', self, self._OnPathMenuClose)
	end
end

function FunBotUIPathMenu:_OnPathMenuRequest(p_Player, p_Data)
	local request = json.decode(p_Data)

	-- Re-enter or hide Data-Menu?
	if request.action == 'data_menu' then
		if self.m_InPathMenu then
			request.action = 'close_comm'
		elseif self.m_NavigaionPath[p_Player.onlineId] and #self.m_NavigaionPath[p_Player.onlineId] > 0 then
			-- Go to last position in menu.
			request.action = self.m_NavigaionPath[p_Player.onlineId][#self.m_NavigaionPath[p_Player.onlineId]]
			self.m_InPathMenu = true
		end
	end

	if request.action == 'unhide_comm' then
		if self.m_NavigaionPath[p_Player.onlineId] and #self.m_NavigaionPath[p_Player.onlineId] > 0 then
			-- Go to last position in menu.
			request.action = self.m_NavigaionPath[p_Player.onlineId][#self.m_NavigaionPath[p_Player.onlineId]]
			self.m_InPathMenu = true
		else
			return
		end
	end

	-- Editor Data-Menu.
	if request.action == 'data_menu' or request.action == 'back_to_data_menu' then
		if not Globals.IsConquest and not Globals.IsRush then
			ChatManager:SendMessage('This menu is not available in this gamemode.', p_Player)
			return
		end
		self.m_InPathMenu = true
		self.m_NavigaionPath[p_Player.onlineId] = {}
		self.m_NavigaionPath[p_Player.onlineId][1] = request.action
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
			}, {
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
			}, {
				Action = 'remove_data',
				Label = Language:I18N('Remove Data')
			}
			}
		end
		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Right = {
				{
					Action = 'add_objective',
					Label = Language:I18N('Add Label / Objective')
				}, {
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
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
		return
	elseif request.action == 'hide_comm' then
		self.m_InPathMenu = false
		NetEvents:SendTo('UI_CommoRose', p_Player, "false")
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
		m_NodeEditor:OnSetLoopMode(p_Player, { "true" })
		return
	elseif request.action == 'invert_path' then
		m_NodeEditor:OnSetLoopMode(p_Player, { "false" })
		return
	elseif request.action == 'set_mcom' then
		m_NodeEditor:OnAddMcom(p_Player)
		return
	elseif request.action == 'set_vehicle_path_type' then
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action
		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'not_implemented',
					Label = Language:I18N('')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Path-Type') -- Or "Unselect".
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
			Bottom = {
				Action = 'vehicle_menu',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'vehicle_menu' then
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
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
				-- Vehicle Menu.
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
		self.m_NavigaionPath[p_Player.onlineId][6] = nil
		self.m_NavigaionPath[p_Player.onlineId][5] = nil
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action
		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'set_vehicle_spawn',
					Label = Language:I18N('Set Vehicle Spawn-Path')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Vehicle') -- Or "Unselect".
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
			Bottom = {
				Action = 'vehicle_menu',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif string.find(request.action, 'add_vehicle_') then
		self.m_NavigaionPath[p_Player.onlineId][5] = nil
		self.m_NavigaionPath[p_Player.onlineId][4] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'not_implemented',
					Label = Language:I18N('')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('Team') -- Or "Unselect".
			},
			Right = {
				{
					Action = 'team_us',
					Label = Language:I18N('US')
				}, {
				Action = 'team_ru',
				Label = Language:I18N('RU')
			}, {
				Action = 'team_both',
				Label = Language:I18N('BOTH')
			}
			},
			Bottom = {
				Action = 'vehicle_objective',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif string.find(request.action, 'team_') then
		self.m_NavigaionPath[p_Player.onlineId][6] = nil
		self.m_NavigaionPath[p_Player.onlineId][5] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
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
		return
	elseif string.find(request.action, 'index_vehcile_') then
		-- FILL THIS.
		local s_Team = self.m_NavigaionPath[p_Player.onlineId][5]:split('_')[2]
		local s_VehicleType = self.m_NavigaionPath[p_Player.onlineId][4]:split('_')[3]
		local s_Index = request.action:split('_')[3]
		local s_ObjectiveData = {}
		table.insert(s_ObjectiveData, "vehicle")
		table.insert(s_ObjectiveData, s_VehicleType .. s_Index)
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
		m_NodeEditor:OnExitVehicle(p_Player, { "true" })
		return
	elseif request.action == 'add_exit_vehicle_all' then
		m_NodeEditor:OnExitVehicle(p_Player, { "false" })
		return
	elseif request.action == 'add_objective' or request.action == 'remove_objective' then
		-- NetEvents:SendTo('UI_Toggle_DataMenu', p_Player, true)
		-- Change Commo-rose.
		self.m_NavigaionPath[p_Player.onlineId][3] = nil
		self.m_NavigaionPath[p_Player.onlineId][2] = request.action
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
			NetEvents:SendTo('UI_CommoRose', p_Player, {
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
						Action = 'point_of_interest',
						Label = Language:I18N('Point of Interst')
					}, {
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
		else -- Conquest.
			NetEvents:SendTo('UI_CommoRose', p_Player, {
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
						Action = 'point_of_interest',
						Label = Language:I18N('Point of Interst')
					}, {
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
	elseif request.action == 'point_of_interest' then
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
			Top = {
				Action = 'not_implemented',
				Label = Language:I18N(''),
				Confirm = true
			},
			Left = {
				{
					Action = 'poi_sniper',
					Label = Language:I18N('Sniper-Spot')
				}
			},
			Center = {
				Action = 'not_implemented',
				Label = Language:I18N('POI') -- Or "Unselect".
			},
			Right = {
				{
					Action = 'poi_beacon',
					Label = Language:I18N('Beacon')
				}
			},
			Bottom = {
				Action = 'add_objective',
				Label = Language:I18N('Back')
			}
		})
		return
	elseif request.action == 'add_mcom' then
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
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
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action

		NetEvents:SendTo('UI_CommoRose', p_Player, {
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
	elseif request.action == 'base_us' or request.action == 'base_ru' or request.action == 'base_rush' then
		if Globals.IsRush then
			self.m_NavigaionPath[p_Player.onlineId][4] = nil
			self.m_NavigaionPath[p_Player.onlineId][3] = request.action
			-- Add index here.
			NetEvents:SendTo('UI_CommoRose', p_Player, {
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
			if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
				m_NodeEditor:OnRemoveObjective(p_Player, s_BaseParts)
			else
				m_NodeEditor:OnAddObjective(p_Player, s_BaseParts)
			end
		end

		return
	elseif string.find(request.action, 'base_us_') or string.find(request.action, 'base_ru_') then
		local s_Data = request.action:split('_')
		if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, s_Data)
		else
			m_NodeEditor:OnAddObjective(p_Player, s_Data)
		end
		return
	elseif string.find(request.action, 'path_type_') then
		local s_Type = request.action:split('_')[3]
		m_NodeEditor:OnAddVehiclePath(p_Player, { s_Type })
	elseif string.find(request.action, 'mcom_') then
		local s_Data = request.action:split('_')
		local s_McomString = "mcom "
		if #s_Data == 2 then
			s_McomString = s_McomString .. s_Data[2]
		elseif #s_Data == 3 then
			s_McomString = s_McomString .. s_Data[3] .. " interact"
		end
		if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, s_McomString:split(' '))
		else
			m_NodeEditor:OnAddObjective(p_Player, s_McomString:split(' '))
		end
		return
	elseif string.find(request.action, 'poi_') then
		local s_Data = request.action:split('_')
		if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, { s_Data[2] })
			m_NodeEditor:OnRemoveData(p_Player)
		else
			m_NodeEditor:OnAddObjective(p_Player, { s_Data[2] })
			m_NodeEditor:OnCustomAction(p_Player, { s_Data[2] })
			m_NodeEditor:OnSetLoopMode(p_Player, { "false" })
		end
		return
	elseif string.find(request.action, 'base_') then
		local s_Data = request.action:split('_')
		if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, s_Data)
		else
			m_NodeEditor:OnAddObjective(p_Player, s_Data)
		end
		return
	elseif string.find(request.action, 'objective_') then
		local s_Objective = request.action:split('_')[2]
		if self.m_NavigaionPath[p_Player.onlineId][2] == "remove_objective" then
			m_NodeEditor:OnRemoveObjective(p_Player, { s_Objective })
		else
			m_NodeEditor:OnAddObjective(p_Player, { s_Objective })
		end
		return
	elseif request.action == 'capture_point' then
		self.m_NavigaionPath[p_Player.onlineId][4] = nil
		self.m_NavigaionPath[p_Player.onlineId][3] = request.action
		NetEvents:SendTo('UI_CommoRose', p_Player, {
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
	else
		print(request.action)
		print("not found")
	end
end

function FunBotUIPathMenu:_OnPathMenuOpen(p_Player)
	self:_OnPathMenuRequest(p_Player, [[{"action":"data_menu"}]])
end

function FunBotUIPathMenu:_OnPathMenuUnhide(p_Player)
	self:_OnPathMenuRequest(p_Player, [[{"action":"unhide_comm"}]])
end

function FunBotUIPathMenu:_OnPathMenuHide(p_Player)
	self:_OnPathMenuRequest(p_Player, [[{"action":"hide_comm"}]])
end

function FunBotUIPathMenu:_OnPathMenuClose(p_Player)
	self:_OnPathMenuRequest(p_Player, [[{"action":"close_comm"}]])
end

if g_FunBotUIPathMenu == nil then
	---@type FunBotUIPathMenu
	g_FunBotUIPathMenu = FunBotUIPathMenu()
end

return g_FunBotUIPathMenu
