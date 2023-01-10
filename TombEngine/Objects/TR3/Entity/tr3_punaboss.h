#pragma once

struct BiteInfo;
struct ItemInfo;

namespace TEN::Entities::Creatures::TR3
{
	void InitialisePuna(short itemNumber);
	void PunaControl(short itemNumber);

	void FirePunaLightning(ItemInfo& item, const Vector3& pos, const BiteInfo& bite, int intensity, bool isSummon);

	short			 GetPunaHeadOrientToTarget(ItemInfo& item, const Vector3& target);
	std::vector<int> GetLizardEntityList(const ItemInfo& item);
	Vector3			 GetLizardTargetPosition(ItemInfo& item);
	int				 GetLizardItemNumber(const ItemInfo& item);

	bool IsLizardActiveNearby(const ItemInfo& item, bool isInitializing = false);

	void SpawnLizard(ItemInfo& item);
	void SpawnSummonSmoke(const Vector3& pos);
}
