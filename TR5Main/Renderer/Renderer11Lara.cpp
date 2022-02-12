#include "framework.h"
#include "Renderer/Renderer11.h"
#include "Game/animation.h"
#include "Game/effects/hair.h"
#include "Game/Lara/lara.h"
#include "Game/control/control.h"
#include "Game/spotcam.h"
#include "Game/camera.h"
#include "Game/collision/sphere.h"
#include "Specific/level.h"
#include "Scripting/GameFlowScript.h"
#include <Specific\setup.h>
#include "Game/Lara/lara_fire.h"
#include "Game/items.h"

using namespace TEN::Renderer;

extern GameFlow *g_GameFlow;

bool shouldAnimateUpperBody(const LARA_WEAPON_TYPE& weapon) {
	ITEM_INFO& laraItem = *LaraItem;
	LaraInfo& laraInfo = Lara;
	switch(weapon){
		case WEAPON_ROCKET_LAUNCHER:
		case WEAPON_HARPOON_GUN:
		case WEAPON_GRENADE_LAUNCHER:
		case WEAPON_CROSSBOW:
		case WEAPON_SHOTGUN:
			return (LaraItem->ActiveState == LS_IDLE || LaraItem->ActiveState == LS_TURN_LEFT_FAST || LaraItem->ActiveState == LS_TURN_RIGHT_FAST || LaraItem->ActiveState == LS_TURN_LEFT_SLOW || LaraItem->ActiveState == LS_TURN_RIGHT_SLOW);
			break;
		case WEAPON_HK:
		{
			//Animate upper body if Lara is shooting from shoulder OR if Lara is standing still/turning
			int baseAnim = Objects[WeaponObject(weapon)].animIndex;
			if(laraInfo.RightArm.AnimNumber - baseAnim == 0 || laraInfo.RightArm.AnimNumber - baseAnim == 2 || laraInfo.RightArm.AnimNumber - baseAnim == 4){
				return true;
			} else
				return (LaraItem->ActiveState == LS_IDLE || LaraItem->ActiveState == LS_TURN_LEFT_FAST || LaraItem->ActiveState == LS_TURN_RIGHT_FAST || LaraItem->ActiveState == LS_TURN_LEFT_SLOW || LaraItem->ActiveState == LS_TURN_RIGHT_SLOW);
		}
			break;
		default:
			return false;
			break;
		
	}
}
void Renderer11::updateLaraAnimations(bool force)
{
	Matrix translation;
	Matrix rotation;
	Matrix lastMatrix;
	Matrix hairMatrix;
	Matrix identity;
	Matrix world;

	RendererItem *item = &m_items[Lara.ItemNumber];
	item->ItemNumber = Lara.ItemNumber;

	if (!force && item->DoneAnimations)
		return;

	RendererObject &laraObj = *m_moveableObjects[ID_LARA];

	// Clear extra rotations
	for (int i = 0; i < laraObj.LinearizedBones.size(); i++)
		laraObj.LinearizedBones[i]->ExtraRotation = Vector3(0.0f, 0.0f, 0.0f);

	// Lara world matrix
	translation = Matrix::CreateTranslation(LaraItem->Position.xPos, LaraItem->Position.yPos, LaraItem->Position.zPos);
	rotation = Matrix::CreateFromYawPitchRoll(TO_RAD(LaraItem->Position.yRot), TO_RAD(LaraItem->Position.xRot), TO_RAD(LaraItem->Position.zRot));

	m_LaraWorldMatrix = rotation * translation;
	item->World = m_LaraWorldMatrix;

	// Update first Lara's animations
	laraObj.LinearizedBones[LM_TORSO]->ExtraRotation = Vector3(TO_RAD(Lara.Control.ExtraTorsoRot.xRot), TO_RAD(Lara.Control.ExtraTorsoRot.yRot), TO_RAD(Lara.Control.ExtraTorsoRot.zRot));
	laraObj.LinearizedBones[LM_HEAD]->ExtraRotation = Vector3(TO_RAD(Lara.Control.ExtraHeadRot.xRot), TO_RAD(Lara.Control.ExtraHeadRot.yRot), TO_RAD(Lara.Control.ExtraHeadRot.zRot));

	// First calculate matrices for legs, hips, head and torso
	int mask = MESH_BITS(LM_HIPS) | MESH_BITS(LM_LTHIGH) | MESH_BITS(LM_LSHIN) | MESH_BITS(LM_LFOOT) | MESH_BITS(LM_RTHIGH) | MESH_BITS(LM_RSHIN) | MESH_BITS(LM_RFOOT) | MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);
	ANIM_FRAME* framePtr[2];
	int rate, frac;

	frac = GetFrame(LaraItem, framePtr, &rate);
	UpdateAnimation(item, laraObj, framePtr, frac, rate, mask);

	// Then the arms, based on current weapon status
	if (Lara.Control.WeaponControl.GunType != WEAPON_FLARE && (Lara.Control.HandStatus == HandStatus::Free || Lara.Control.HandStatus == HandStatus::Busy) || Lara.Control.WeaponControl.GunType == WEAPON_FLARE && !Lara.Flare.ControlLeft)
	{
		// Both arms
		mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND) | MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
		frac = GetFrame(LaraItem, framePtr, &rate);
		UpdateAnimation(item, laraObj, framePtr, frac, rate, mask);
	}
	else
	{
		// While handling weapon some extra rotation could be applied to arms
		if (Lara.Control.WeaponControl.GunType == WEAPON_PISTOLS || Lara.Control.WeaponControl.GunType == WEAPON_UZI)
		{
			laraObj.LinearizedBones[LM_LINARM]->ExtraRotation += Vector3(TO_RAD(Lara.LeftArm.Rotation.xRot), TO_RAD(Lara.LeftArm.Rotation.yRot), TO_RAD(Lara.LeftArm.Rotation.zRot));
			laraObj.LinearizedBones[LM_RINARM]->ExtraRotation += Vector3(TO_RAD(Lara.RightArm.Rotation.xRot), TO_RAD(Lara.RightArm.Rotation.yRot), TO_RAD(Lara.RightArm.Rotation.zRot));
		}
		else
		{
			laraObj.LinearizedBones[LM_RINARM]->ExtraRotation += Vector3(TO_RAD(Lara.RightArm.Rotation.xRot), TO_RAD(Lara.RightArm.Rotation.yRot), TO_RAD(Lara.RightArm.Rotation.zRot));
			laraObj.LinearizedBones[LM_LINARM]->ExtraRotation = laraObj.LinearizedBones[LM_RINARM]->ExtraRotation;
		}

		ArmInfo *leftArm = &Lara.LeftArm;
		ArmInfo *rightArm = &Lara.RightArm;

		// HACK: backguns handles differently // TokyoSU: not really a hack since it's the original way to do that.
		switch (Lara.Control.WeaponControl.GunType)
		{
		case WEAPON_SHOTGUN:
		case WEAPON_HK:
		case WEAPON_CROSSBOW:
		case WEAPON_GRENADE_LAUNCHER:
		case WEAPON_ROCKET_LAUNCHER:
		case WEAPON_HARPOON_GUN:
		{
			ANIM_FRAME* shotgunFramePtr;

			// Left arm
			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);

			if(shouldAnimateUpperBody(Lara.Control.WeaponControl.GunType)){
				mask |= MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);
			}
			shotgunFramePtr = &g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber];
			UpdateAnimation(item, laraObj, &shotgunFramePtr, 0, 1, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			if(shouldAnimateUpperBody(Lara.Control.WeaponControl.GunType)){
				mask |= MESH_BITS(LM_TORSO) | MESH_BITS(LM_HEAD);
			}
			shotgunFramePtr = &g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber];
			UpdateAnimation(item, laraObj, &shotgunFramePtr, 0, 1, mask);
		}
			break;
		case WEAPON_REVOLVER:
		{
			ANIM_FRAME* revolverFramePtr;

			// Left arm
			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);
			revolverFramePtr = &g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - g_Level.Anims[Lara.LeftArm.AnimNumber].frameBase];
			UpdateAnimation(item, laraObj, &revolverFramePtr, 0, 1, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			revolverFramePtr = &g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - g_Level.Anims[Lara.RightArm.AnimNumber].frameBase];
			UpdateAnimation(item, laraObj, &revolverFramePtr, 0, 1, mask);
		}
			break;

		case WEAPON_PISTOLS:
		case WEAPON_UZI:
		default:
		{
			ANIM_FRAME* pistolFramePtr;

			// Left arm
			int upperArmMask = MESH_BITS(LM_LINARM);
			mask = MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);
			pistolFramePtr = &g_Level.Frames[Lara.LeftArm.FrameBase + Lara.LeftArm.FrameNumber - g_Level.Anims[Lara.LeftArm.AnimNumber].frameBase];
			UpdateAnimation(item, laraObj, &pistolFramePtr, 0, 1, upperArmMask, true);
			UpdateAnimation(item, laraObj, &pistolFramePtr, 0, 1, mask);

			// Right arm
			upperArmMask = MESH_BITS(LM_RINARM);
			mask = MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			pistolFramePtr = &g_Level.Frames[Lara.RightArm.FrameBase + Lara.RightArm.FrameNumber - g_Level.Anims[Lara.RightArm.AnimNumber].frameBase];
			UpdateAnimation(item, laraObj, &pistolFramePtr, 0, 1, upperArmMask, true);
			UpdateAnimation(item, laraObj, &pistolFramePtr, 0, 1, mask);
		}

		break;

		case WEAPON_FLARE:
		case WEAPON_TORCH:
			// Left arm
			LaraItem->AnimNumber = Lara.LeftArm.AnimNumber;
			LaraItem->FrameNumber = Lara.LeftArm.FrameNumber;

			mask = MESH_BITS(LM_LINARM) | MESH_BITS(LM_LOUTARM) | MESH_BITS(LM_LHAND);
			frac = GetFrame(LaraItem, framePtr, &rate);
			UpdateAnimation(item, laraObj, framePtr, frac, rate, mask);

			// Right arm
			mask = MESH_BITS(LM_RINARM) | MESH_BITS(LM_ROUTARM) | MESH_BITS(LM_RHAND);
			frac = GetFrame(LaraItem, framePtr, &rate);
			UpdateAnimation(item, laraObj, framePtr, frac, rate, mask);
			break;
		}
	}

	// Copy matrices in Lara object
	for (int m = 0; m < 15; m++)
		laraObj.AnimationTransforms[m] = item->AnimationTransforms[m];

	m_items[Lara.ItemNumber].DoneAnimations = true;
}

void TEN::Renderer::Renderer11::DrawLara(bool shadowMap, RenderView& view)
{
	// Don't draw Lara if binoculars or sniper
	if (BinocularRange || SpotcamOverlay || SpotcamDontDrawLara || CurrentLevel == 0)
		return;

	UINT stride = sizeof(RendererVertex);
	UINT offset = 0;

	m_context->IASetVertexBuffers(0, 1, m_moveablesVertexBuffer.Buffer.GetAddressOf(), &stride, &offset);
	m_context->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
	m_context->IASetInputLayout(m_inputLayout.Get());
	m_context->IASetIndexBuffer(m_moveablesIndexBuffer.Buffer.Get(), DXGI_FORMAT_R32_UINT, 0);

	RendererItem* item = &m_items[Lara.ItemNumber];

	// Set shaders
	if (shadowMap)
	{
		m_context->VSSetShader(m_vsShadowMap.Get(), NULL, 0);
		m_context->PSSetShader(m_psShadowMap.Get(), NULL, 0);
	}
	else
	{
		m_context->VSSetShader(m_vsItems.Get(), NULL, 0);
		m_context->PSSetShader(m_psItems.Get(), NULL, 0);
	}

	// Set texture
	BindTexture(TextureRegister::MainTexture, &std::get<0>(m_moveablesTextures[0]), SamplerStateType::LinearClamp);
	BindTexture(TextureRegister::NormalMapTexture, &std::get<1>(m_moveablesTextures[0]), SamplerStateType::None);

	m_stMisc.AlphaTest = true;
	m_cbMisc.updateData(m_stMisc, m_context.Get());
	m_context->PSSetConstantBuffers(3, 1, m_cbMisc.get());

	RendererObject& laraObj = *m_moveableObjects[ID_LARA];
	RendererObject& laraSkin = *m_moveableObjects[ID_LARA_SKIN];
	RendererRoom* room = &m_rooms[LaraItem->RoomNumber];

	m_stItem.World = m_LaraWorldMatrix;
	m_stItem.Position = Vector4(LaraItem->Position.xPos, LaraItem->Position.yPos, LaraItem->Position.zPos, 1.0f);
	m_stItem.AmbientLight = item->AmbientLight;
	memcpy(m_stItem.BonesMatrices, laraObj.AnimationTransforms.data(), sizeof(Matrix) * 32);
	m_cbItem.updateData(m_stItem, m_context.Get());
	m_context->VSSetConstantBuffers(1, 1, m_cbItem.get());
	m_context->PSSetConstantBuffers(1, 1, m_cbItem.get());

	if (!shadowMap)
	{
		m_stLights.NumLights = item->LightsToDraw.size();
		for (int j = 0; j < item->LightsToDraw.size(); j++)
			memcpy(&m_stLights.Lights[j], item->LightsToDraw[j], sizeof(ShaderLight));
		m_cbLights.updateData(m_stLights, m_context.Get());
		m_context->PSSetConstantBuffers(2, 1, m_cbLights.get());
	}

	for (int k = 0; k < laraSkin.ObjectMeshes.size(); k++)
	{
		RendererMesh *mesh = GetMesh(Lara.meshPtrs[k]);
		drawMoveableMesh(item, mesh, room, k);
	}

	DrawLaraHolsters();

	if (m_moveableObjects[ID_LARA_SKIN_JOINTS].has_value())
	{
		RendererObject &laraSkinJoints = *m_moveableObjects[ID_LARA_SKIN_JOINTS];
		RendererObject& laraSkin = *m_moveableObjects[ID_LARA_SKIN];

		for (int k = 1; k < laraSkinJoints.ObjectMeshes.size(); k++)
		{
			RendererMesh *mesh = laraSkinJoints.ObjectMeshes[k];
			drawMoveableMesh(item, mesh, room, k);
		}
	}

	if (Objects[ID_LARA_HAIR].loaded)
	{
		RendererObject& hairsObj = *m_moveableObjects[ID_LARA_HAIR];

		// First matrix is Lara's head matrix, then all 6 hairs matrices. Bones are adjusted at load time for accounting this.
		m_stItem.World = Matrix::Identity;
		Matrix matrices[7];
		matrices[0] = laraObj.AnimationTransforms[LM_HEAD] * m_LaraWorldMatrix;
		for (int i = 0; i < hairsObj.BindPoseTransforms.size(); i++)
		{
			HAIR_STRUCT* hairs = &Hairs[0][i];
			Matrix world = Matrix::CreateFromYawPitchRoll(TO_RAD(hairs->pos.yRot), TO_RAD(hairs->pos.xRot), 0) * Matrix::CreateTranslation(hairs->pos.xPos, hairs->pos.yPos, hairs->pos.zPos);
			matrices[i + 1] = world;
		}
		memcpy(m_stItem.BonesMatrices, matrices, sizeof(Matrix) * 7);
		m_cbItem.updateData(m_stItem,m_context.Get());
		m_context->VSSetConstantBuffers(1, 1, m_cbItem.get());
		m_context->PSSetConstantBuffers(1, 1, m_cbItem.get());

		for (int k = 0; k < hairsObj.ObjectMeshes.size(); k++)
		{
			RendererMesh* mesh = hairsObj.ObjectMeshes[k];
			drawMoveableMesh(item, mesh, room, k);
		}	
	}
}

void Renderer11::DrawLaraHolsters()
{
	RendererItem* item = &m_items[Lara.ItemNumber];
	RendererRoom* room = &m_rooms[LaraItem->RoomNumber];

	HolsterSlot leftHolsterID = Lara.Control.WeaponControl.HolsterInfo.LeftHolster;
	HolsterSlot rightHolsterID = Lara.Control.WeaponControl.HolsterInfo.RightHolster;
	HolsterSlot backHolsterID = Lara.Control.WeaponControl.HolsterInfo.BackHolster;

	if(m_moveableObjects[static_cast<int>(leftHolsterID)])
	{
		RendererObject& holsterSkin = *m_moveableObjects[static_cast<int>(leftHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_LTHIGH];
		drawMoveableMesh(item, mesh, room, LM_LTHIGH);
	}

	if(m_moveableObjects[static_cast<int>(rightHolsterID)]){
		RendererObject& holsterSkin = *m_moveableObjects[static_cast<int>(rightHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_RTHIGH];
		drawMoveableMesh(item, mesh, room, LM_RTHIGH);
	}

	if(backHolsterID != HolsterSlot::Empty && m_moveableObjects[static_cast<int>(backHolsterID)]){
		RendererObject& holsterSkin = *m_moveableObjects[static_cast<int>(backHolsterID)];
		RendererMesh* mesh = holsterSkin.ObjectMeshes[LM_TORSO];
		drawMoveableMesh(item, mesh, room, LM_TORSO);
	}
}

