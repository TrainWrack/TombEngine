#pragma once

#include "Specific/RGBAColor8Byte.h"

enum class WeatherType
{
	None,
	Rain,
	Snow
};

enum class LaraType
{
	Normal = 1,
	Young = 2,
	Bunhead = 3,
	Catsuit = 4,
	Divesuit = 5,
	Invisible = 7
};

class ScriptInterfaceLevel
{
public:
	bool Horizon = false;
	bool Rumble	 = false;

	std::string NameStringKey	   = {};
	std::string FileName		   = {};
	std::string ScriptFileName	   = {};
	std::string LoadScreenFileName = {};

	virtual ~ScriptInterfaceLevel() = default;

	virtual bool GetSkyLayerEnabled(int index) const = 0;
	virtual short GetSkyLayerSpeed(int index) const = 0;
	virtual LaraType GetLaraType() const = 0;
	virtual bool GetStormEnabled() const = 0;
	virtual float GetWeatherStrength() const = 0;
	virtual WeatherType GetWeatherType() const = 0;
	virtual RGBAColor8Byte GetSkyLayerColor(int index) const = 0;
	virtual bool GetFogEnabled() const = 0;
	virtual RGBAColor8Byte GetFogColor() const = 0;
	virtual short GetFogMinDistance() const = 0;
	virtual short GetFogMaxDistance() const = 0;
	virtual short GetFarView() const = 0;
	virtual int GetSecrets() const = 0;
	virtual std::string GetAmbientTrack() const = 0;
	virtual bool GetResetHubEnabled() const = 0;

	// Lens flare getters
	virtual bool  GetLensFlareEnabled() const = 0;
	virtual int	  GetLensFlareSunSpriteID() const = 0;
	virtual short GetLensFlarePitch() const = 0;
	virtual short GetLensFlareYaw() const = 0;
	virtual Color GetLensFlareColor() const = 0;

	// Starfield getters
	virtual bool  GetStarfieldStarsEnabled() const = 0;
	virtual bool  GetStarfieldMeteorsEnabled() const = 0;
	virtual int	  GetStarfieldStarCount() const = 0;
	virtual int	  GetStarfieldMeteorCount() const = 0;
	virtual int	  GetStarfieldMeteorSpawnDensity() const = 0;
	virtual float GetStarfieldMeteorVelocity() const = 0;
};
