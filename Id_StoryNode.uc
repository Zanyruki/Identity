class Id_StoryNode extends Id_InteractableBase
ClassGroup( Identity )
placeable;

var() string                              StoryNodeIndex;
var() string                              StoryNodeRecipient;
var() string                              StoryNodeSender;
var() string                              StoryNodeSubject;

var StaticMeshComponent                   ItemMesh;
var Id_GFxStoryMenu                       StoryMenu;
var MaterialInstance                      FlashMaterial;
var MaterialInstance                      BlankMaterial;
var TextureRenderTarget2D                 MenuRenderTexture;
var MovementState                         prevPlayerMovementState;

var MaterialInstance                      ScreenMaterial;

const Xoffset = 0.0;//-5.0;
const Yoffset = 0.0;//20.0;
const Zoffset = 0.0;//18.0;
const ScreenMaterialIndex = 1;
const ScreenBackgroundMaterialIndex = 2;

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

function EnableScreenEmail( optional bool enable = true )
{
    ScreenMaterial.SetScalarParameterValue('DISTORTION SWITCH', 0.0 );
    ScreenMaterial.SetScalarParameterValue('EMAIL SWITCH', (enable)? 1.0 : 0.0 );
}

function bool Interact( Id_PlayerController PC )
{
	if (!bIsHacked)
	{
        //ItemMesh.SetMaterial( ScreenBackgroundMaterialIndex, ScreenMaterial );
        EnableScreenDistortion();
		return Hack( PC );
	}
	else
	{
		`log("SN INTERACT: INTERACT");
		prevPlayerMovementState = Id_PlayerPawn(PC.Pawn).playerMovementState;
		Id_PlayerPawn( PC.Pawn ).setMovementState( Movement_Hacking );
		
		//Id_HUDWrapper(PC.myHUD).MyHUDMovie.SetMoreInfo(self.bMoreInfoLarge, MoreInfoString);
		ActivateStoryNode( PC );
		return true;
	}
}


function SuccessfulHack( Id_PlayerController PC )
{
	`log("SN HACK");
	super.SuccessfulHack( PC );
	prevPlayerMovementState = Id_PlayerPawn(PC.Pawn).playerMovementState;
	//Id_HUDWrapper(PC.myHUD).MyHUDMovie.SetMoreInfo(self.bMoreInfoLarge, MoreInfoString);
	ActivateStoryNode( PC );
	
}

function FailedHack( Id_PlayerController PC )
{
    ResetScreen();
    //ItemMesh.SetMaterial( ScreenBackgroundMaterialIndex, DefaultMaterial );
}


function Vector getHackingParticleLocation()
{
	local vector Xaxes, Yaxes, Zaxes, alright;
	GetAxes( self.Rotation, Xaxes, Yaxes, Zaxes );
	`log( "X axis: " @ Xaxes );
	alright = self.Location + ( Xaxes * Xoffset ) + ( Yaxes * Yoffset ) + ( Zaxes * Zoffset );
	return alright;
}


function bool CanInteract()
{
	local float dotProduct;//, playerDot;
	dotProduct = ( Normal( vector( GetALocalPlayerController().Pawn.Rotation ) ) dot Normal( vector( Rotation ) ) );
	//playerDot = ( Normal( vector( GetALocalPlayerController().Rotation ) ) dot Normal( vector( Rotation ) ) );
	return dotProduct > 0.8 && super.CanInteract();
}





function ActivateStoryNode( Id_PlayerController PC )
{
	local string storyNodeText, storyToText, storyFromText, storySubjectText;
	local array< string > storyNodeWords;
	
	//local array< string > textPerScreen;
	self.TriggerEventClass(class'Id_SeqEvent_StoryNodeClicked', self );
	ItemMesh.SetMaterial( ScreenMaterialIndex, FlashMaterial );
	//ItemMesh.SetMaterial( ScreenBackgroundMaterialIndex, BackgroundMaterial );
	EnableScreenEmail();
	PC.OpenStoryMenu( self );


	storyNodeText = Id_GameInfo( WorldInfo.Game ).LocalizedStringManager.getText( StoryNodeIndex );
	ParseStringIntoArray( storyNodeText, storyNodeWords, "``", true );
	storyNodeText   = storyNodeWords[ 0 ];
	storyFromText   = storyNodeWords[ 1 ];
	storyToText     = storyNodeWords[ 2 ];//Id_GameInfo( WorldInfo.Game ).LocalizedStringManager.getText( StoryNodeRecipient );
	//Id_GameInfo( WorldInfo.Game ).LocalizedStringManager.getText( StoryNodeSender );
	storySubjectText = storyNodeWords[ 3 ];//Id_GameInfo( WorldInfo.Game ).LocalizedStringManager.getText( StoryNodeSubject );

	StoryMenu  = new class'Id_GFxStoryMenu';
	
	`log( "StoryNodeText: " @ storyNodeText );
	StoryMenu.setStoryNodeText( storyNodeText, storyToText, storyFromText, storySubjectText );
	StoryMenu.RenderTexture = MenuRenderTexture;
	StoryMenu.RenderTextureMode = RTM_AlphaComposite;

	//PC.SetCinematicMode( true, false, true, true, true, false );
	StoryMenu.Start();

	StoryMenu.AddCaptureKey( 'W' );
	StoryMenu.AddCaptureKey( 'S' );
	StoryMenu.AddCaptureKey( 'A' );
	StoryMenu.AddCaptureKey( 'D' );
	StoryMenu.AddCaptureKey( 'Q' );
	StoryMenu.AddCaptureKey( 'E' );
	StoryMenu.AddCaptureKey( 'C' );
	StoryMenu.AddCaptureKey( 'Alt' );
	StoryMenu.AddCaptureKey( 'Spacebar' );
	StoryMenu.AddCaptureKey( 'Up' );
	StoryMenu.AddCaptureKey( 'Down' );
	StoryMenu.AddCaptureKey( 'Enter' );
	StoryMenu.AddCaptureKey( 'Gamepad_LeftStick_Left' );
	StoryMenu.AddCaptureKey( 'Gamepad_LeftStick_Right' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_DPad_Left' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_DPad_Right' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_LeftThumbstick' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_LeftY' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_LeftX' );
	StoryMenu.AddCaptureKey( 'XboxTypeS_RightY' );
	
}


function CloseGfxMenuTimer()
{
// 	local Id_PlayerController PC;
// 	PC = Id_PlayerController( GetALocalPlayerController() );
	StoryMenu.Close();
	//PC.SetCinematicMode( false, false, true, true, true, false );
}


function CloseMenu()
{
	//local PlayerController PC;
	//PlaySound( ShutDownSound,,,, Location );
	ItemMesh.SetMaterial( ScreenMaterialIndex, BlankMaterial );
	//ItemMesh.SetMaterial( ScreenBackgroundMaterialIndex, DefaultMaterial );
	EnableScreenEmail( false );
	SetTimer( 0.67, false, 'CloseGfxMenuTimer' );
	StoryMenu.ClearCaptureKeys();
	//Id_PlayerController( GetALocalPlayerController() ).LockPlayerInput();

	//Id_PlayerPawn( GetALocalPlayerController().Pawn).setMovementState(prevPlayerMovementState);
}


simulated function SetOverlayMaterial(MaterialInterface NewOverlay)
{

    // If we are authoritative, then set up replication of the new overlay
    if (Role == ROLE_Authority)
    {
        OverlayMaterialInstance = NewOverlay;
    }

    /*if (SkeletalMesh != None)
    {
        if (NewOverlay != None)
        {
            `log( "WAERGLEBARGLE " );
            OverlaySkeletalMesh.SetMaterial(0, OverlayMaterialInstance);
			OverlaySkeletalMesh.SetMaterial(1, OverlayMaterialInstance);
			OverlaySkeletalMesh.SetMaterial(2, BlankMaterial );
			OverlaySkeletalMesh.SetMaterial(3, BlankMaterial );

            // attach the overlay mesh
            if (!OverlaySkeletalMesh.bAttached)
            {
                AttachComponent(OverlaySkeletalMesh);
            }
        }
        else if (OverlaySkeletalMesh.bAttached)
        {
            DetachComponent(OverlaySkeletalMesh);
        }
    }*/

	if (StaticMesh != none)
	{
		if (NewOverlay != None)
        {
			//OverlayStaticMesh.SetMaterial(0, OverlayMaterialInstance);
			//OverlayStaticMesh.SetMaterial(ScreenMaterialIndex, BlankMaterial );
			//OverlayStaticMesh.SetMaterial(ScreenBackgroundMaterialIndex, BlankMaterial );

            // attach the overlay mesh
            //if (!OverlayStaticMesh.bAttached)
            //{
            //    AttachComponent(OverlayStaticMesh);
            //}
        }
        //else if (OverlayStaticMesh.bAttached)
        //{
        //    DetachComponent(OverlayStaticMesh);
        //}
	}
}
simulated event PostBeginPlay()
{
	StaticMesh = ItemMesh;
	super.PostBeginPlay();

	if (!bIsHackable)
	{
		bIsHacked = true;
	}
	ScreenMaterial = StaticMesh.CreateAndSetMaterialInstanceConstant(2);
}

DefaultProperties
{
	bStatic = false;
    bNoDelete = true;
    bAlwaysRelevant = true;
    bWorldGeometry = false

	bIsHackable=true
	InteractDistance=240.0
	bIsHacked=false

	InteractSymbolOffset=(X=30.0,Y=0.0,Z=50.0)
	bHasMoreInfo = true
	MoreInfoString=""

	Begin Object Class=StaticMeshComponent Name=TerminalMesh
      StaticMesh=StaticMesh'ID_Story_Notes.StaticMesh.Id_story_note_sm_01'
      bAllowApproximateOcclusion=TRUE
      bForceDirectLightMap=TRUE
      bUsePrecomputedShadows=TRUE
    End Object
	ItemMesh = TerminalMesh
    CollisionComponent = TerminalMesh
    Components.Add(TerminalMesh)

	FlashMaterial = MaterialInstanceConstant'IdentityStoryMenu.Material.StoryNodeFlashMaterial_INST'
	BlankMaterial =	MaterialInstanceConstant'ID_Screen_Materials.MaterialInstanceConstant.TransparentScreen_INST'
	MenuRenderTexture = TextureRenderTarget2D'IdentityStoryMenu.Material.IdentityStoryRenderTexture'

    bCollideActors = true
    bBlockActors = true
	SupportedEvents.Add(class'Id_SeqEvent_StoryNodeClicked')

    NumberOfHackingBars = HACK_MEDIUM
}
