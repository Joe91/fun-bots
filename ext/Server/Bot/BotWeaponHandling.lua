---@param p_DeltaTime number
---@param p_Deploy boolean
function Bot:UpdateDeployAndReload(p_DeltaTime, p_Deploy)
	if self._ActiveAction == BotActionFlags.MeleeActive or self._ActiveAction == BotActionFlags.OtherActionActive or self.m_Player.soldier == nil then
		return
	end
	self._WeaponToUse = BotWeapons.Primary
	self:_ResetActionFlag(BotActionFlags.C4Active)
	self:_ResetActionFlag(BotActionFlags.ReviveActive)
	self:_ResetActionFlag(BotActionFlags.RepairActive)
	self:_ResetActionFlag(BotActionFlags.EnterVehicleActive)
	self:_ResetActionFlag(BotActionFlags.GrenadeActive)
	self:AbortAttack()

	if self._ActiveAction ~= BotActionFlags.OtherActionActive then
		self._TargetPitch = 0.0
	end

	self._ReloadTimer = self._ReloadTimer + p_DeltaTime

	-- reload primary weapon
	if self.m_ActiveWeapon ~= nil and self._ReloadTimer > 1.5 and self._ReloadTimer < 2.55 and
		self.m_Player.soldier.weaponsComponent.weapons[1] and
		self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo <= self.m_ActiveWeapon.reload then
		self:_SetInput(EntryInputActionEnum.EIAReload, 1)
	end

	-- keep nades filled
	if self.m_Player.soldier.weaponsComponent.weapons[7] and self.m_Player.soldier.weaponsComponent.weapons[7].primaryAmmo <= 0 then
		self.m_Player.soldier.weaponsComponent.weapons[7].primaryAmmo = 1
		self.m_Player.soldier.weaponsComponent.weapons[7].secondaryAmmo = 0
	end

	-- Deploy from time to time.
	if Config.BotsDeploy and p_Deploy and not Globals.IsScavenger then
		if self.m_PrimaryGadget ~= nil and (self.m_Kit == BotKits.Support or self.m_Kit == BotKits.Assault) then
			if self.m_PrimaryGadget.type == WeaponTypes.Ammobag or self.m_PrimaryGadget.type == WeaponTypes.Medkit then
				self._DeployTimer = self._DeployTimer + p_DeltaTime

				if self._DeployTimer > Config.DeployCycle then
					self._DeployTimer = 0.0
				end

				if self._DeployTimer < 0.7 then
					self._WeaponToUse = BotWeapons.Gadget1
				end
			end
		end
	end
end

---@param p_DeltaTime number
function Bot:UpdateWeaponSelection(p_DeltaTime)
	-- Select weapon-slot.
	if self._ActiveAction ~= BotActionFlags.MeleeActive then
		if self.m_Player.soldier.weaponsComponent ~= nil then
			if self.m_KnifeMode then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_7 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon7, 1)
					self.m_ActiveWeapon = self.m_Knife
					self._ShotTimer = 0.0
				end
			elseif self._ActiveAction == BotActionFlags.ReviveActive or self._ActiveAction == BotActionFlags.RepairActive or
				(self._WeaponToUse == BotWeapons.Gadget2 and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Gadget2 then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_5 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon5, 1)
					self.m_ActiveWeapon = self.m_SecondaryGadget
					self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)
				end
			elseif (self._WeaponToUse == BotWeapons.Gadget1 and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Gadget1 then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_2 and
					self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_4 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon4, 1)
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon3, 1)
					self.m_ActiveWeapon = self.m_PrimaryGadget
					self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)
				end
			elseif self._ActiveAction == BotActionFlags.GrenadeActive or
				(self._WeaponToUse == BotWeapons.Grenade and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Grenade then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_6 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon6, 1)
					self.m_ActiveWeapon = self.m_Grenade
					self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, false)
				end
			elseif (self._WeaponToUse == BotWeapons.Pistol and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Pistol then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_1 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon2, 1)
					self.m_ActiveWeapon = self.m_Pistol
					self._ShotTimer = -self:GetFirstShotDelay(self._DistanceToPlayer, true)
				end
				if self.m_Player.soldier.weaponsComponent.weapons[2] and
					self.m_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo <
					self.m_Player.soldier.weaponsComponent.weapons[2].primaryAmmo + 1 then
					-- keep pistol filled
					self.m_Player.soldier.weaponsComponent.weapons[2].secondaryAmmo = self.m_Player.soldier.weaponsComponent.weapons[
					2].primaryAmmo + 3
				end
			elseif (self._WeaponToUse == BotWeapons.Primary and Config.BotWeapon == BotWeapons.Auto) or
				Config.BotWeapon == BotWeapons.Primary then
				if self.m_Player.soldier.weaponsComponent.currentWeaponSlot ~= WeaponSlot.WeaponSlot_0 then
					self:_SetInput(EntryInputActionEnum.EIASelectWeapon1, 1)
					self.m_ActiveWeapon = self.m_Primary
					self._ShotTimer = -0.05
				end
				-- keep primary filled
				if self.m_Player.soldier.weaponsComponent.weapons[1] and
					self.m_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo <
					self.m_Player.soldier.weaponsComponent.weapons[1].primaryAmmo + 1 then
					self.m_Player.soldier.weaponsComponent.weapons[1].secondaryAmmo = self.m_Player.soldier.weaponsComponent.weapons[
					1].primaryAmmo + 3
				end
			end
		end
	end

	if self._RocketCooldownTimer >= 0 then
		self._RocketCooldownTimer = self._RocketCooldownTimer - p_DeltaTime
	end
end
