class Id_DistractionItem extends Id_InteractableBase
	ClassGroup( Identity )
	placeable
	dependson( Id_DistractionLocation );

var() StaticMeshComponent                   ItemMesh;
var() const float							GuardAlertRadius;   // Alert guards within this radius
var() SoundCue                              DistractionSound;   //optional sound cue
var() bool                                  bCanHack;
var() Id_GuardBasePawn                      GuardToDistract;    //Specific guard to distract, if not set, will pick the closest guard
var() float                                 DeactivationTime;    // Time it takes for a guard to stop the Distraction Item.
var() Id_DistractionLocation                DistractionLocation; // Area where guards will path to.
var(Debug) bool                             bDrawSphere;

var private AudioComponent                  DistractionAudioComponent;
var bool                                    bIsDistracting;
var private bool                            bIsClaimed;
var private Id_BasicAIController            ClosestDistractedGuard;
var private Id_DecalActorSpawnable          DistractionRadiusRing;
var private Id_DecalActorSpawnable          DistractionRadiusRingArchetype;
var private Vector                          MeshCenter;
var private Id_GuardHologram                GuardHologram;
var private SkeletalMesh                    GuardHologramMesh;
var private Id_GuardBasePawn                GuardHologramArchtype;

var MaterialInstance                        ScreenMaterial;

simulated event PostBeginPlay()
{
	//local MaterialInstanceConstant tempMatConst;
	local float meshRadius;

	ActionString = "DistractionActionName1";
	
	bIsHackable = bCanHack;
	StaticMesh = ItemMesh;
	super.PostBeginPlay();

	/*DistractionRadiusRing = Spawn( DistractionRadiusRingArchetype.Class, Self,, Location, Rot(49152, 0, 0), DistractionRadiusRingArchetype );
	tempMatConst = new class'MaterialInstanceConstant';
    tempMatConst.SetParent(  DistractionRadiusRing.Decal.GetDecalMaterial() );
    DistractionRadiusRing.Decal.SetDecalMaterial( tempMatConst );
    Attach( DistractionRadiusRing );*/
	
	meshRadius = ItemMesh.Bounds.SphereRadius / 2;
    //DistractionRadiusRing.Decal.Width = 2.25* GuardAlertRadius;
    //DistractionRadiusRing.Decal.Height = 2.25* GuardAlertRadius;
	MeshCenter = Location;
	MeshCenter.X += meshRadius;
	MeshCenter.Y += meshRadius;
	//DistractionRadiusRing.SetLocation( MeshCenter );
	//DistractionRadiusRing.SetHidden( true );

	GuardHologram = Spawn( class'Id_GuardHologram',, , DistractionLocation.Location, DistractionLocation.Rotation );
	if( DistractionLocation.bHasSetUp )
	{
		GuardHologram.SetLocation( DistractionLocation.Location - vect( 0, 0, 44 ) );
	}
	GuardHologram.SetHidden( true );
	//GuardHologram

	DistractionAudioComponent = CreateAudioComponent( DistractionSound, false, true, true, MeshCenter, true );

    ScreenMaterial = StaticMesh.CreateAndSetMaterialInstanceConstant(0);
    ResetScreen();
}




//Material functions
function ResetScreen( optional bool bResetVideo = true )
{
	ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', 0.0 );
   
	if( bResetVideo )
	{
		`log( "LOL reset" );
		ScreenMaterial.SetScalarParameterValue('VIDEO SWITCH', 0.0 );
	}
}

function EnableScreenDistortion( optional bool enable = true )
{
    ScreenMaterial.SetScalarParameterValue('VIDEO SWITCH', 0.0 );
    ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', (enable)? 1.0 : 0.0 );
}

function EnableScreenVideo( optional bool enable = true )
{
    ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', 0.0 );
    ScreenMaterial.SetScalarParameterValue('VIDEO SWITCH', (enable)? 1.0 : 0.0 );
    ScreenMaterial.SetScalarParameterValue('VIDEO SELECT', float(rand(2)));
}

function bool Interact( Id_PlayerController PC )
{
	if( bIsHackable && !bIsHacked )
	{
        EnableScreenDistortion();
		Hack( PC );
	}
	else
	{
		if( !bIsDistracting )
		{
			self.TriggerEventClass(class'Id_SeqEvent_Interact', self, 0 ); // Interact Kismet Event
			SetOffDistraction();
			return true;
		}
		return false;
	}
}

function FailedHack( Id_PlayerController PC )
{
    super.FailedHack( PC );
    ResetScreen( false );
}


function SuccessfulHack( Id_PlayerController PC )
{
	super.SuccessfulHack( PC );
	Interact( PC );
}


/*function SecondaryAction( Id_PlayerController PC )
{
	local Id_ThirdPersonCamera thirdPersonCamera;
	local Id_PlayerCamera customPlayerCamera;
	local Rotator AngleToClosestGuard;

	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
	thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);
	thirdPersonCamera.bInBetweenOrientation = true;
	thirdPersonCamera.DesiredCameraOrientation = CameraOrientation_Guard;
	AngleToClosestGuard = Rotation;
	thirdPersonCamera.OrientationTargetRotation = AngleToClosestGuard;
}*/


function EndSecondaryAction( Id_PlayerController PC )
{
	local Id_ThirdPersonCamera thirdPersonCamera;
	local Id_PlayerCamera customPlayerCamera;
	//local Rotator AngleToClosestGuard;

	customPlayerCamera = Id_PlayerCamera(PC.PlayerCamera);
	thirdPersonCamera = Id_ThirdPersonCamera(customPlayerCamera.ThirdPersonCam);
	thirdPersonCamera.DesiredCameraOrientation = CameraOrientation_Player;
	InteractIndicator.SetMoreInfoHidden(false);
}


function Id_BasicAIController getClosestGuard()
{
	local Id_BasicAIController closestGuard;
	local Id_GuardBasePawn guardPawn;
	local float closestDistance;
	local float distanceToGuard;
	local Id_BasicAIController guardController;

	closestGuard = none;
	closestDistance = -1.0;
	foreach WorldInfo.AllPawns( class'Id_GuardBasePawn', guardPawn, MeshCenter, GuardAlertRadius )
	{
		guardController = ID_BasicAIController( guardPawn.Controller );
		if( ! ( guardController.bAlarmed ) )
		{
			distanceToGuard = VSize( MeshCenter - guardPawn.Location );
            if( Id_BasicAIController( GuardPawn.Controller ).FindNavMeshPath( DistractionLocation ) )
            {
                distanceToGuard = Id_BasicAIController( guardPawn.Controller).NavigationHandle.CalculatePathDistance( DistractionLocation.Location );
			    if( distanceToGuard < closestDistance || closestDistance < 0)
			    {
				    closestDistance = distanceToGuard;
				    closestGuard = guardController;
			    }
            }
		}
	}

	return closestGuard;

}


function DistractionTimer()
{
	if( GuardToDistract != none )
	{
		Id_BasicAIController( GuardToDistract.Controller ).DistractGuard( self );
		return;
	}
	else if( ClosestDistractedGuard != none )
	{
		if( ClosestDistractedGuard.bDistracted )
		{
			return;
		}
		else
		{
			ClosestDistractedGuard = none;
		}
	}

	ClosestDistractedGuard = getClosestGuard();

	ClosestDistractedGuard.DistractGuard( self );
	
}


function InterruptedDeactivation()
{
	ClearTimer( 'TurnOffTimer' );
    bIsClaimed = false;
}

function SetOffDistraction()
{
	if( DistractionSound != none )
	{
		DistractionAudioComponent.Play();
	}
	bIsDistracting = true;
    EnableScreenVideo();
	DistractionTimer();
	SetTimer( 3.0, true, 'DistractionTimer' );
}

function TurnOffTimer()
{
	local Id_GuardBasePawn guardPawn;

	bIsDistracting = false;
	bIsClaimed = false;
	ClearTimer( 'DistractionTimer' );
	DistractionAudioComponent.Stop();
	ForEach WorldInfo.AllPawns(class'Id_GuardBasePawn', guardPawn )
	{
		if( Id_BasicAIController( guardPawn.Controller ).DistractionItemToInvestigate == self )
			Id_BasicAIController( guardPawn.Controller ).DistractionTurnedOff();
	}

	if (Id_PlayerController(GetALocalPlayerController()).SelectedActor != self)
	{
		InteractIndicator.PlayFadeOut();
	}

    ResetScreen();
}

event Destroyed()
{
    TurnOffTimer();
}


function turnOffDistraction()
{
	if( !bIsClaimed )
	{
		bIsClaimed = true;
		SetTimer( DeactivationTime, false, 'TurnOfftimer' );
	}
}

function OnCurrentlySelected()
{
	Super.OnCurrentlySelected();
	//DistractionRadiusRing.SetHidden( false );
	GuardHologram.SetHidden( false );

}

function OffCurrentlySelected()
{
	Super.OffCurrentlySelected();
	DisableOverlay();
	DistractionRadiusRing.SetHidden( true );
	Id_GuardBasePawn( ClosestDistractedGuard.Pawn ).DisableOverlay();
	GuardHologram.SetHidden( true );
}

function WhileSelectedTick()
{
	//local vector newPos;
	ClosestDistractedGuard = getClosestGuard();
	if( ClosestDistractedGuard != none )
	{
		//Id_GuardBasePawn( ClosestDistractedGuard.Pawn ).SetOverlayMaterial( OverlayMat );
	}

	//DrawDebugLine( Location, Location + vect( -GuardAlertRadius,0,0 ), 255, 0, 0 );
	//DrawDebugLine( Location, Location + vect( 0, GuardAlertRadius,0 ), 255, 0, 0 );
	//DrawDebugLine( Location, Location + vect( 0, -GuardAlertRadius,0 ), 255, 0, 0 );
	//`log( "Terminal is selected" );
	/*if( LockedActor != none )
	{
		DrawDebugLine( Location, LockedActor.Location, 255, 0, 0 );
		//OverlayStaticMesh.SetStaticMesh( StaticMesh( InterpActor( LockedActor ).StaticMesh ) );
	}*/
}

event Tick( float DeltaTime )
{
	super.Tick( DeltaTime );
	if( bDrawSphere )
	{
		DrawDebugSphere( MeshCenter, GuardAlertRadius, 12, 255, 0, 255 );
	}
	InteractIndicator.UpdateDistracting(bIsDistracting, self.GetRemainingTimeForTimer('TurnOfftimer')/self.DeactivationTime);
}


DefaultProperties
{
	
	Begin Object Class=StaticMeshComponent Name=ItemMesh0
	  StaticMesh=StaticMesh'ID_Light_Fixtures.static_mesh.Id_lamp_sk_01'
	  CastShadow=FALSE
	  bCastDynamicShadow=FALSE
	  bAcceptsLights=TRUE
	End Object
	ItemMesh = ItemMesh0
	CollisionComponent = ItemMesh0
	Components.Add(ItemMesh0)
	bBlockActors = true
	bCollideActors = true

	/*Begin Object Class=SkeletalMeshComponent Name=HologramGuard
		SkeletalMesh=SkeletalMesh'Id_Guard.SkeletalMesh.id_guard_sk_13'
		CastShadow=FALSE
	  bCastDynamicShadow=FALSE
	  bAcceptsLights=TRUE
	End Object*/
	GuardHologramMesh = SkeletalMesh'Id_Guard.SkeletalMesh.id_guard_sk_13'

	DistractionRadiusRingArchetype = Id_DecalActorSpawnable'Id_Scalzo.ShadowArchetype'

	bCanHack = false
	bIsClaimed = false
	bIsDistracting = false
	DeactivationTime = 1.0
	bHasMoreInfo = true

	MoreInfoTitle = "DISTRACTION ITEM"

	DistractionSound = SoundCue'ID_Sounds_Environment.Environment.ID_Distraction_02_Cue'

    NumberOfHackingBars = HACK_MEDIUM
}
