#pragma once

struct CollisionInfo;
struct ItemInfo;

namespace TEN::Entities::Traps
{
	void InitializeZipLineOld(short itemNumber);
	void CollideZipLineOld(short itemNumber, ItemInfo* laraItem, CollisionInfo* coll);
	void ControlZipLineOld(short itemNumber);
}
