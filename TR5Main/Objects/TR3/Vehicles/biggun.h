#pragma once

struct COLL_INFO;
struct ITEM_INFO;

void BigGunInitialise(short itemNumber);
static bool BigGunTestMount(ITEM_INFO* laraItem, ITEM_INFO* bGunItem);
void BigGunFire(ITEM_INFO* laraItem, ITEM_INFO* bGunItem);
void BigGunCollision(short itemNumber, ITEM_INFO* laraItem, COLL_INFO* coll);
bool BigGunControl(ITEM_INFO* laraItem, COLL_INFO* coll);
