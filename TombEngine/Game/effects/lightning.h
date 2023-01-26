#pragma once
#include <cstddef>
#include <vector>

#include "Math/Math.h"

namespace TEN::Effects::ElectricArc
{
	constexpr auto ELECTRIC_ARC_KNOTS_SIZE	= 6;
	constexpr auto ELECTRIC_ARC_BUFFER_SIZE = 1024;

	enum ElectricArcFlags
	{
		LI_SPLINE	= (1 << 0),
		LI_MOVEEND	= (1 << 1),
		LI_THINOUT	= (1 << 2),
		LI_THININ	= (1 << 3),
		LI_SPARKEND = (1 << 4)
	};

	// TODO: Make sense of this struct.
	struct ElectricArc
	{
		Vector3 pos1;
		Vector3 pos2;
		Vector3 pos3;
		Vector3 pos4;
		std::array<Vector3, 3> interpolation = {};

		byte r;
		byte g;
		byte b;

		float life;
		float sLife;
		float amplitude;
		float sAmplitude;
		float width;
		unsigned int segments;

		int segmentSize;
		int direction;
		int rotation;
		int type;
		int flags;
	};

	struct HelicalLaser
	{
		unsigned int NumSegments = 0;

		Vector3 Origin		  = Vector3::Zero;
		Vector3 Target		  = Vector3::Zero;
		short	Orientation2D = 0;
		Vector3 LightPosition = Vector3::Zero; // TODO: Use light cone instead?
		Vector4 Color		  = Vector4::Zero;

		float Life		= 0.0f;
		float Radius	= 0.0f;
		float Length	= 0.0f;
		float LengthEnd = 0.0f;
		float Opacity	= 0.0f;
		short Rotation	= 0;
	};

	extern std::vector<ElectricArc>	 ElectricArcs;
	extern std::vector<HelicalLaser> HelicalLasers;

	extern std::array<Vector3, ELECTRIC_ARC_KNOTS_SIZE>	 ElectricArcKnots;
	extern std::array<Vector3, ELECTRIC_ARC_BUFFER_SIZE> ElectricArcBuffer;

	void SpawnElectricArc(const Vector3& origin, const Vector3& target, float amplitude, byte r, byte g, byte b, float life, int flags, float width, unsigned int numSegments);
	void SpawnElectricArcGlow(const Vector3& pos, float scale, byte r, byte g, byte b);
	void SpawnHelicalLaser(const Vector3& origin, const Vector3& target);

	void UpdateElectricArcs();
	void UpdateHelicalLasers();

	void CalculateElectricArcSpline(const ElectricArc& arc, const std::array<Vector3, ELECTRIC_ARC_KNOTS_SIZE>& posArray, std::array<Vector3, ELECTRIC_ARC_BUFFER_SIZE>& bufferArray);
	void CalculateHelixSpline(const HelicalLaser& laser, std::array<Vector3, ELECTRIC_ARC_KNOTS_SIZE>& posArray, std::array<Vector3, ELECTRIC_ARC_BUFFER_SIZE>& bufferArray);
}
