class('GameDirector');


function GameDirector:__init()
	self._captuePoints = {}
	Events:Subscribe('CapturePoint:Lost', self, self._onLost)
	Events:Subscribe('CapturePoint:Captured', self, self._onCapture)
end

function GameDirector:initGamemode(gameMode)
	if gameMode == "Conquest" then
		-- extract all objectives from paths
	end
end

function GameDirector:_onCapture(capturePoint)
	
end

function GameDirector:_onLost(capturePoint)
	
end