class Id_Terminal extends Id_InteractableBase
    ClassGroup( Identity )
    placeable;

/********************************************************
 * Basic Terminal Implementation                        *
 *                                                      *
 ********************************************************/

var(Camera) CameraActor CameraTarget;
var(Camera) float CameraWaitTime;
var(Camera) float CameraInterpolationTime;

var(Unlock) array<InterpActor> LockedActors;
var(Unlock) bool AllowUnlockDoors;
var(Unlock) bool AllowUnlockShutters;

var(ServerRoom) bool bUnlockServer;

var(Checkpoint) Id_Checkpoint Checkpoint; //The checkpoint to use when opened. Note: If guards are alarmed (actively pursuing), terminal is disabled

var SoundCue StartUpSound;
var SoundCue ShutDownSound;

var InterpActor LockedActor0;
var InterpActor LockedActor1;


//PRIVATE VARIABLES
var     bool					bIsLocked;
var private MaterialInstance             DefaultMaterial;
var private MaterialInstance             OpenSourceMaterial;
var private MaterialInstance             BlankMaterial;
var private MaterialInstance             BackgroundMaterial;
var private MaterialInstance             AltColorMaterial;
var private MaterialInstance             AltColorMaterialHacked;
var private MaterialInstance             TerminalHackedMaterial;

var MaterialInstance                        ScreenMaterial;

var     DynamicLightEnvironmentComponent LightEnvironment;
var private float                        LastDeltaTime;
var private float                        FocusInterpolationRate;

var private StaticMeshComponent LockedActorOverlayStaticMesh0;
var private StaticMeshComponent LockedActorOverlayStaticMesh1;

const Xoffset = -5.0;
const Yoffset = 10.0;
const Zoffset = 75.0;

const ScreenMaterialIndex = 3;
const ScreenBackgroundMaterialIndex = 2;

// InteractableBase Methods
function bool Interact( Id_PlayerController PC )
{
	if( !bIsInteractable && !bIsHackable )
	{
		return false;
	}
	if( bIsHacked )
	{
		self.TriggerEventClass(class'Id_SeqEvent_Interact', self, 0 ); // Interact Kismet Event
		ActivateTerminal( PC );
		return true;
	}
	else
	{
		return Hack( PC );
	}
}

function Vector getHackingParticleLocation()
{
	local vector Xaxes, Yaxes, Zaxes, alright;
	GetAxes( self.Rotation, Xaxes, Yaxes, Zaxes );
	`log( "X axis: " @ Xaxes );
	alright = self.Location + ( Xaxes * Xoffset ) + ( Yaxes * Yoffset ) + ( Zaxes * Zoffset );
	return alright;
}

//Material functions
function ResetScreen()
{
    ScreenMaterial.SetScalarParameterValue('Video Clip Enable', 0.0 );
    ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', 0.0 );
}

function EnableScreenDistortion( optional bool enable = true )
{
    ScreenMaterial.SetScalarParameterValue('Video Clip Enable', 0.0 );
    ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', (enable)? 1.0 : 0.0 );
}

function bool Hack( Id_PlayerController PC )
{
    EnableScreenDistortion();

	return super.Hack( PC );
	//if( Id_GameInfo( WorldInfo.Game ).NumberOfChasingGuards == 0 && !bIsLocked )
	//{
	//	return super.Hack( PC );
	//}
	//else
	//{
	//	PlaySound( PC.WrongButtonSound );
	//}
}


function SuccessfulHack( Id_PlayerController PC )
{
	super.SuccessfulHack( PC );

	if( Checkpoint != none )
    {
        Checkpoint.activateCheckpoint();
    }
	ActivateTerminal( PC );
}

function FailedHack( Id_PlayerController PC )
{
    Super.FailedHack(PC);
    ResetScreen();
	//bIsLocked = true;
	/*if( GuardToInvestigate != none )
	{
		ID_BasicAIController( GuardToInvestigate.Controller ).InvestigateLocation( Location + vect( 0, 0, 40 ) );
	}*/
	//SetTimer( LockedTime, false, 'UnlockTimer' );
}


//function bool CanInteract()
//{
//	local float dotProduct;//, playerDot;
//	dotProduct = ( Normal( vector( GetALocalPlayerController().Pawn.Rotation ) ) dot Normal( vector( Rotation ) ) );
//	//playerDot = ( Normal( vector( GetALocalPlayerController().Rotation ) ) dot Normal( vector( Rotation ) ) );
//	return dotProduct > 0.8 && super.CanInteract();
//}


function SetOverlayOnActor( InterpActor LockedActor, StaticMeshComponent Overlay )
{
	local int i;
	
	//Overlay.SetStaticMesh( LockedActor.StaticMeshComponent.StaticMesh );
	for (i = 0; i < 10; i++)
	{
		Overlay.SetMaterial(i, OverlayMaterialInstance);
	}
	LockedActor.AttachComponent( Overlay );
	
}


function removeOverlayOnActor( InterpActor LockedActor, StaticMeshComponent Overlay )
{
		LockedActor.DetachComponent( Overlay );
}


function OnCurrentlySelected()
{
	Super.OnCurrentlySelected();

	if( LockedActor0 != none )
	{
		SetOverlayOnActor( LockedActor0, LockedActorOverlayStaticMesh0 );
	}
	if( LockedActor1 != none )
	{
		SetOverlayOnActor( LockedActor1, LockedActorOverlayStaticMesh1 );
	}
}


function OffCurrentlySelected()
{
	Super.OffCurrentlySelected();

	if( LockedActor0 != none )
	{
		removeOverlayOnActor( LockedActor0, LockedActorOverlayStaticMesh0 );
	}
	if( LockedActor1 != none )
	{
		removeOverlayOnActor( LockedActor1, LockedActorOverlayStaticMesh1 );
	}

	if (self.bIsInteractable || bIsHackable)
	{
		InteractOutOfRange.SetVisibility(true);
	}
	else
	{
		InteractOutOfRange.SetVisibility(false);
	}
}

function LoadTerminalState( bool bActivated )
{
    if( bActivated )
    {
        self.TriggerEventClass(class'Id_SeqEvent_TerminalUse', self, 0 );
        if( bUnlockServer )
        {
            Id_GameInfo( WorldInfo.Game ).numServersToRaise++;
        }
        SetTerminalAsUsed();
    }
    else
    {
        
    }
}


function ActivateTerminal( Id_PlayerController PC )
{
	if( AllowUnlockDoors )
	{
		UnlockDoors();
        SkeletalMesh.SetMaterial( 0, TerminalHackedMaterial );
	}
	else if( bUnlockServer )
	{
		moveServerRoom();
        SkeletalMesh.SetMaterial( 0, AltColorMaterialHacked );
	}
	else
	{
		//PC.OpenTerminalMenu( self );
        SkeletalMesh.SetMaterial( 0, TerminalHackedMaterial );
        SkeletalMesh.SetMaterial( ScreenBackgroundMaterialIndex, OpenSourceMaterial );
	}
}


simulated function SetOverlayMaterial(MaterialInterface NewOverlay)
{

    // If we are authoritative, then set up replication of the new overlay
    if (Role == ROLE_Authority)
    {
        OverlayMaterialInstance = NewOverlay;
    }

    if (SkeletalMesh != None)
    {
        if (NewOverlay != None)
        {
            `log( "WAERGLEBARGLE " );
           //OverlaySkeletalMesh.SetMaterial(0, OverlayMaterialInstance);
			//OverlaySkeletalMesh.SetMaterial(1, OverlayMaterialInstance);
           //
			//OverlaySkeletalMesh.SetMaterial(ScreenBackgroundMaterialIndex, BlankMaterial );
			//OverlaySkeletalMesh.SetMaterial(ScreenMaterialIndex, BlankMaterial );
           //OverlaySkeletalMesh.SetMaterial( 1, BlankMaterial);

            // attach the overlay mesh
            //if (!OverlaySkeletalMesh.bAttached)
            //{
            //    AttachComponent(OverlaySkeletalMesh);
            //}
        }
        //else if (OverlaySkeletalMesh.bAttached)
        //{
        //    DetachComponent(OverlaySkeletalMesh);
        //}
    }
}


simulated event PostBeginPlay()
{
	NameString = "TerminalName";
	//ActionString = "TerminalActionName1";

	super.PostBeginPlay();

	
	if( AllowUnlockShutters )
	{
		//NameString = "TerminalOpenShuttersName";
		AllowUnlockDoors = true;
	}
	else if( AllowUnlockDoors )
	{
		//NameString = "TerminalOpenDoorsName";
	}
	else if( bUnlockServer )
	{
		//NameString = "TerminalRaiseServerName";
		SkeletalMesh.SetMaterial( 0, AltColorMaterial );
	}

    
    ScreenMaterial = SkeletalMesh.CreateAndSetMaterialInstanceConstant(ScreenBackgroundMaterialIndex);
}


function SetTerminalAsUsed()
{
	bIsIgnored = true;
	bIsHackable = false;
	bIsInteractable = false;
	SkeletalMesh.SetMaterial( ScreenBackgroundMaterialIndex, OpenSourceMaterial );
}


function LockPlayerInput()
{
	local PlayerController PC;
	PC = GetALocalPlayerController();
	PC.IgnoreLookInput( true );
	PC.IgnoreMoveInput( true );
}

function UnlockPlayerInput()
{
	local PlayerController PC;
	PC = GetALocalPlayerController();
	PC.IgnoreLookInput( false );
	PC.IgnoreMoveInput( false );
	Id_PlayerController( PC ).bIsInMenu = false;
}


function UnlockDoorCallback()
{
	local PlayerController PC;
	local Id_ThirdPersonCamera thirdPersonCamera;
    local Id_PlayerCamera customPlayerCamera;

	PC = GetALocalPlayerController();
	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
    thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);
	thirdPersonCamera.DesiredCamOrientation = PC.Pawn.Rotation;
	
}


function UnlockDoorTimer()
{
	local PlayerController PC;
	local Id_ThirdPersonCamera thirdPersonCamera;
    local Id_PlayerCamera customPlayerCamera;

	PC = GetALocalPlayerController();
	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
    thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);

	
	thirdPersonCamera.SetCameraOrientationInterpolation( CameraOrientation_Player, PC.Pawn.Rotation,, UnlockDoorCallback );
	thirdPersonCamera.SetCameraFocusInterpolation( CameraFocus_Player, PC.Pawn.Location, FocusInterpolationRate, UnlockPlayerInput, 10.0 );
	thirdPersonCamera.SetCameraOffset( CameraLean_Center );
}


function UnlockDoors()
{
	local PlayerController PC;
	local Id_ThirdPersonCamera thirdPersonCamera;
    local Id_PlayerCamera customPlayerCamera;
	local float distanceToCameraActor;

    if( CameraTarget != none )
	{
		PC = GetALocalPlayerController();
		PC.IgnoreLookInput( true );
		PC.IgnoreMoveInput( true );
		Id_PlayerController( PC ).bIsInMenu = true;
		customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
		thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);

		distanceToCameraActor = VSize( PC.Pawn.Location - CameraTarget.Location );
		FocusInterpolationRate = distanceToCameraActor * LastDeltaTime / CameraInterpolationTime;


		thirdPersonCamera.SetCameraOrientationInterpolation( CameraOrientation_Matinee, CameraTarget.Rotation, 0.15, OnFinishUnlockInterpolation );
		thirdPersonCamera.SetCameraFocusInterpolation( CameraFocus_Matinee, CameraTarget.Location, FocusInterpolationRate ,OnFinishUnlockInterpolation );
		thirdPersonCamera.SetCameraOffset( CameraLean_FirstPerson );
		//thirdPersonCamera.DesiredCameraLean = CameraLean_FirstPerson;
	}
	else
	{
		self.TriggerEventClass(class'Id_SeqEvent_TerminalUse', self, 0 ); // Unlock Doors
	}

	SetTerminalAsUsed();
}


function OnFinishUnlockInterpolation()
{
	self.TriggerEventClass(class'Id_SeqEvent_TerminalUse', self, 0 ); // Unlock Doors
	SetTimer( CameraWaitTime, false, 'UnlockDoorTimer' );
}


function ServerRoomTimer()
{
	local PlayerController PC;
	local Id_ThirdPersonCamera thirdPersonCamera;
    local Id_PlayerCamera customPlayerCamera;
	PC = GetALocalPlayerController();
	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
    thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);

	thirdPersonCamera.DesiredCameraOrientation = CameraOrientation_Player;
	thirdPersonCamera.newFocusLocation = self.Location;
	thirdPersonCamera.DesiredCamOrientation = thirdPersonCamera.OrientationTargetRotation;
	UnlockPlayerInput();
}

function moveServerRoom()
{
	local PlayerController PC;
	local Id_ThirdPersonCamera thirdPersonCamera;
    local Id_PlayerCamera customPlayerCamera;
	PC = GetALocalPlayerController();
	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
    thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);

	self.TriggerEventClass(class'Id_SeqEvent_TerminalUse', self, 2 );

	thirdPersonCamera.newFocusLocation = CameraTarget.Location;
	thirdPersonCamera.DesiredCamOrientation = CameraTarget.Rotation;
	thirdPersonCamera.DesiredCameraOrientation = CameraOrientation_Matinee;
	LockPlayerInput();
	SetTimer( CameraWaitTime, false, 'ServerRoomTimer' );
	SetTerminalAsUsed();

}

simulated event PostRenderFor( PlayerController PC, Canvas Canvas, vector CameraPosition, vector CameraDir )
{

	super.PostRenderFor(PC, Canvas, CameraPosition, CameraDir);
    //local vector screenLoc;
    
    //if( bIsSelected )
    //{
    //    //`log(" *** Was selected!");
    //    screenLoc = Canvas.Project( Location + 100 * vect( 0, 0, 1 ) );

    //    //Clipping screen space
    //    if (screenLoc.X < 0 ||
    //        screenLoc.X >= Canvas.ClipX ||
    //        screenLoc.Y < 0 ||
    //        screenLoc.Y >= Canvas.ClipY)
    //    {
    //        return;
    //    }

    //    Canvas.Font = class'Engine'.static.GetLargeFont();
    //    Canvas.SetPos( 0, 0 );

    //    Canvas.DrawText( "SELECTED! " );
    //    bIsSelected = false;
    //}
}


event Tick( float DeltaTime )
{
	Super.Tick( DeltaTime );
	LastDeltaTime = DeltaTime;
}
function UnlockTimer()
{
	bIsLocked = false;
}

DefaultProperties
{
    bStatic = false;
    bNoDelete = true;
    bAlwaysRelevant = true;
    bWorldGeometry = false

	SupportedEvents.Add(class'Id_SeqEvent_TerminalUse')
    

    Begin Object Class=DynamicLightEnvironmentComponent Name=MyLightEnvironment
		bSynthesizeSHLight=TRUE
		bIsCharacterLightEnvironment=TRUE
		bUseBooleanEnvironmentShadowing=FALSE
		InvisibleUpdateTime=1
		MinTimeBetweenFullUpdates=.2
	End Object
	Components.Add(MyLightEnvironment)
	LightEnvironment=MyLightEnvironment

    //Static Mesh component
    Begin Object Class=SkeletalMeshComponent Name=TerminalMesh
      SkeletalMesh=SkeletalMesh'ID_Terminal_Security_Camera.skeletal_mesh.Id_terminal03_sk_01'
	  //PhysAsset=PhysicsAsset'ID_Physics.terminal.Id_terminal_sk_01_Physics'
	  /*AnimSets.Add(AnimSet'ID_Terminal_Security_Camera.skeletal_mesh.Id_terminal_animset_01')
	  AnimTreeTemplate=AnimTree'ID_Terminal_Security_Camera.animation.Id_terminal_sk_01_AnimTree'
	  MorphSets[0]=MorphTargetSet'ID_Terminal_Security_Camera.Id_terminal_sk_01_MorphTargetSet'*/
      bAllowApproximateOcclusion=TRUE
      bForceDirectLightMap=TRUE
      bUsePrecomputedShadows=TRUE
	  Translation=( X=-15.0, Y = 25.0 )
	  Rotation=(Yaw=16384)
      LightEnvironment=MyLightEnvironment
    End Object

	//Begin Object  Class=StaticMeshComponent Name=LockedOverlayMeshComponent0
    //    Scale=1.015
    //    bAcceptsDynamicDecals=false
    //    CastShadow=false
    //    bOwnerNoSee=true
    //    TickGroup=TG_PostAsyncWork
    //    DepthPriorityGroup=SDPG_World
    //End Object
    //LockedActorOverlayStaticMesh0=LockedOverlayMeshComponent0

	//Begin Object  Class=StaticMeshComponent Name=LockedOverlayMeshComponent1
    //    Scale=1.015
    //    bAcceptsDynamicDecals=false
    //    CastShadow=false
    //    bOwnerNoSee=true
    //    TickGroup=TG_PostAsyncWork
    //    DepthPriorityGroup=SDPG_World
    //End Object
    //LockedActorOverlayStaticMesh1=LockedOverlayMeshComponent1

    //CollisionComponent = TerminalMesh
    SkeletalMesh = TerminalMesh
    Components.Add(TerminalMesh)
	Begin Object Class=CylinderComponent Name=CollisionCylinder
		CollisionRadius=+0028.000000
		CollisionHeight=+0078.000000
		BlockNonZeroExtent=true
		BlockZeroExtent=true
		BlockActors=true
		CollideActors=true
		//Translation=(X=15, Y=-30)
	End Object
	CollisionComponent = TerminalMesh
	Components.Add( CollisionCylinder );

	//FlashMaterial = MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.TerminalFlashMaterial_INST'
	DefaultMaterial = MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.Id_story_note_screen_mat_01_INST'
	OpenSourceMaterial = MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.Id_terminal_opensource_screen_mat_01_INST'
	BlankMaterial =	MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.TransparentScreen_INST'
	BackgroundMaterial = MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.Id_terminal_screen_mat_01_INST'
	AltColorMaterial = MaterialInstanceConstant'ID_Terminal_Security_Camera.Texture.Id_terminal03_variant_mat_01_INST_locked'
    AltColorMaterialHacked = MaterialInstanceConstant'ID_Terminal_Security_Camera.Texture.Id_terminal03_variant_mat_01_INST'
	TerminalHackedMaterial = MaterialInstanceConstant'ID_Terminal_Security_Camera.Texture.Id_terminal_03_mic_01'
	//MenuRenderTexture = TextureRenderTarget2D'ID_Screen_Materials.Texture.TerminalFlashRenderTexture'


    bCollideActors = true
    bBlockActors = true


    //StoredIdentity = new class'Id_IdentityInfo'


	AllowUnlockDoors      = false
	bUnlockServer = false

	CameraWaitTime = 3.5
	CameraInterpolationTime = 1.0

	

	StartUpSound = SoundCue'ID_Sounds_Terminal.TerminalUp_Cue'
	ShutDownSound = SoundCue'ID_Sounds_Terminal.TerminalDown_Cue'

    //DEBUG
	bIsHackable = true
	bIsInteractable = true
	bIsHacked = false
	bIsLocked = false

	InteractSymbolOffset=(X=0.0,Y=0.0,Z=110.0)
	TargetOffset=(X=0.0,Y=8.0,Z=60.0)
	InteractDistance = 100

	//NameString = "TERMINAL"
	MoreInfoTitle = "TERMINAL"
	MoreInfoSize = MI_Medium;

    NumberOfHackingBars = HACK_MEDIUM
	
}
