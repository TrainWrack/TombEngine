#include "framework.h"
#include "Game/pickup/pickup_consumable.h"

#include <array>

#include "Game/Lara/lara_struct.h"
#include "Game/pickup/pickuputil.h"
#include "Objects/objectslist.h"

struct ConsumablePickupInfo
{
	GAME_OBJECT_ID ObjectID;
	// Pointer to array of consumable in question
	int PlayerInventoryData::* Count;
	// How many of the item to give the player if the caller
	// does not specify; i.e. default amount per pickup
	int Amount;
};

static constexpr std::array<ConsumablePickupInfo, 4> kConsumables =
{
	{
		{ ID_SMALLMEDI_ITEM, &PlayerInventoryData::TotalSmallMedipacks, 1 },
		{ ID_BIGMEDI_ITEM, &PlayerInventoryData::TotalLargeMedipacks, 1 },
		{ ID_FLARE_INV_ITEM, &PlayerInventoryData::TotalFlares, 12 },
		{ ID_FLARE_ITEM, &PlayerInventoryData::TotalFlares, 1 }
	}
 };

bool TryModifyingConsumable(LaraInfo& lara, GAME_OBJECT_ID objectID, std::optional<int> amount, ModificationType modType)
{
	int arrayPos = GetArraySlot(kConsumables, objectID);
	if (arrayPos == NO_VALUE)
		return false;

	ConsumablePickupInfo info = kConsumables[arrayPos];
	auto & currentAmt = lara.Inventory.*(info.Count);
	switch (modType)
	{
	case ModificationType::Set:
		currentAmt = amount.value();
		break;

	default:
		if (currentAmt != NO_VALUE)
		{
			int defaultModify = ModificationType::Add == modType ? info.Amount : -info.Amount;
			int newVal = currentAmt + (amount.has_value() ? amount.value() : defaultModify);
			currentAmt = std::max(0, newVal);
		}
		break;
	}

	return true;
}

bool TryAddingConsumable(LaraInfo& lara, GAME_OBJECT_ID objectID, std::optional<int> amount)
{
	return TryModifyingConsumable(lara, objectID, amount, ModificationType::Add);
}

bool TryRemovingConsumable(LaraInfo& lara, GAME_OBJECT_ID objectID, std::optional<int> amount)
{
	if (amount.has_value())
		return TryModifyingConsumable(lara, objectID, -amount.value(), ModificationType::Remove);
	else
		return TryModifyingConsumable(lara, objectID, amount, ModificationType::Remove);
}

std::optional<int> GetConsumableCount(LaraInfo& lara, GAME_OBJECT_ID objectID)
{
	int arrayPos = GetArraySlot(kConsumables, objectID);
	if (arrayPos == NO_VALUE)
		return std::nullopt;

	ConsumablePickupInfo info = kConsumables[arrayPos];

	return lara.Inventory.*(info.Count);
}

int GetDefaultConsumableCount(GAME_OBJECT_ID objectID)
{
	int arrayPos = GetArraySlot(kConsumables, objectID);
	if (arrayPos == NO_VALUE)
		return NO_VALUE;

	return kConsumables[arrayPos].Amount;
}