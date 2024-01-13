extends CharacterBody2D


const SPEED = 300.0
const DASH_SPEED = 700.0
const RUN_SPEED = 500
const AIR_DASH_SPEED_HORIZONTAL_ONLY = 700.0
const AIR_DASH_SPEED_VERTICAL = 450.0

const SUPER_JUMP_VELOCITY = -820.0
const JUMP_VELOCITY = -450.0
const SUPER_JUMP_TIMING = 0.25
const DASH_STOP_TIME = 0.20
const DUCK_STOP_TIME = 0.1
const DOUBLE_TAP_DASH_TIME = 0.1
const MAX_DASHES_PER_JUMP = 1
const MAX_JUMPS_PER_JUMP = 1
const MAX_WALLJUMPS_PER_JUMP = 99999
const MAX_WALLCLING_PER_JUMP = 1
const MAX_WALL_SLIDE_SPEED = 65.0
const WALL_SLIDE_ACCELERATION = 1;
const ATTACK_SLIDE_FACTOR = 11
const SLIDE_FACTOR = 10

var curDashSpeed = DASH_SPEED
var curDashStopTime = DASH_STOP_TIME
var curDuckStopTime = DUCK_STOP_TIME
var curDoubleTapDashTime = 0
var superJumpDownTimer = 0
var curWallSlideSpeed = -10

var attackDetails = {
	'light_punch': {
		'active': 2,
		'cooldown': 3,
		'position': Vector2 (30, -20),
		'size': Vector2(30, 30),
		'knockback': Vector2(500, -1000)
	},
	'heavy_punch': {
		'active': 4,
		'cooldown': 6,
		'position': Vector2 (35, -45),
		'size': Vector2(40, 55),
		'knockback': Vector2(1000, -13000)
	},
	'light_kick': {
		'active': 1,
		'cooldown': 2,
		'position': Vector2 (30, 10),
		'size': Vector2(40, 20),
		'knockback': Vector2(500, -1000)
	},
	'heavy_kick': {
		'active': 3,
		'cooldown': 4,
		'position': Vector2 (30, -15),
		'size': Vector2(35, 30),
		'knockback': Vector2(8000, -2500)
	},
	'heavy_kick_air': {
		'active': 2,
		'cooldown': 3,
		'position': Vector2 (0, 20),
		'size': Vector2(85, 35),
		'knockback': Vector2(12000, 2500)
	}
}

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var wasAirBorn = false;
var wasBackDash = false;
var lastDirection = 0;
var isSuperJump = false;
var curYDirection = 0;
var curXDirection = 0;
var curDashesinOneJump = 0;
var curJumpsinOneJump = 0;
var curWallClingsInOneJump = 0
var curWallJumpsInOneJump = 0
var curAttackFrame = 0
var curAttackDetails = null
var curAttackHitOrBlocked = false

func _physics_process(delta):
	$AnimatedSprite2D.play()
	
	# Initialize variables
	var curDirection
	if $AnimatedSprite2D.flip_h:
		curDirection = -1;
	else:
		curDirection = 1;
		
	var direction = Input.get_axis("move_left", "move_right")
	var ydirection = Input.get_axis("jump", "duck")
	
	# Processing for air or ground
	if not is_on_floor():
		if $AnimatedSprite2D.animation != 'flight':
			velocity.y += gravity * delta
		else:
			pass
		wasAirBorn = true
	else:
		isSuperJump = false
		curDashesinOneJump = 0
		curJumpsinOneJump = 0
		curWallClingsInOneJump = 0
		curWallJumpsInOneJump = 0
		if wasAirBorn:
			$AnimatedSprite2D.animation = 'slide'
			disableHitBox()
		wasAirBorn = false;
		
		
	# Check timers for multi frame inputs
	if curDoubleTapDashTime > 0:
		curDoubleTapDashTime -= delta
	elif curDoubleTapDashTime < 0:
		curDoubleTapDashTime = 0;
		
	if superJumpDownTimer > 0:
		superJumpDownTimer -= delta
	elif superJumpDownTimer < 0:
		superJumpDownTimer = 0;
		
		
	# Process State - 3 Phases
	# Phase 1 - Process break
	if Input.is_action_just_pressed("light_punch") && Input.is_action_just_pressed("light_kick"):
		if not is_on_floor():
			if curJumpsinOneJump < MAX_JUMPS_PER_JUMP:
				$AnimatedSprite2D.animation = 'jump'
				curJumpsinOneJump += 1
				velocity.x = 0
				velocity.y = 0
		else:
			$AnimatedSprite2D.animation = 'idle'
		if curAttackDetails:
			cancelAttack()
	# Phase 2 - Process states that terminate on a timer.
	elif $AnimatedSprite2D.animation == "fall":
		velocity.x = move_toward(velocity.x, 0, SPEED / ATTACK_SLIDE_FACTOR)
		
	elif Input.is_action_just_pressed("heavy_kick") && Input.is_action_just_pressed("light_kick"):
		if $AnimatedSprite2D.animation == 'flight':
			$AnimatedSprite2D.animation = 'jump'
		else:
			$AnimatedSprite2D.animation = 'flight'
			if is_on_floor():
				velocity.y = -50
			else:
				velocity.y = 0
			velocity.x = 0
			if curAttackDetails:
				cancelAttack()

	# Handle Jump.
	elif $AnimatedSprite2D.animation == "heavy_punch" || $AnimatedSprite2D.animation == "light_punch" || $AnimatedSprite2D.animation == "heavy_kick" || $AnimatedSprite2D.animation == "heavy_kick_air" || $AnimatedSprite2D.animation == "light_kick":
	# Let animation play out
		curAttackDetails = attackDetails[$AnimatedSprite2D.animation]
		if curAttackFrame >= curAttackDetails.active:
			activateHitBox(curDirection, curAttackDetails['position'], curAttackDetails['size']);
		elif curAttackFrame >= curAttackDetails.cooldown:
			disableHitBox();
	
		if is_on_floor():
			# on ground, just slide
			if curAttackHitOrBlocked && Input.is_action_pressed("jump"):
				superJumpDownTimer = 1
				cancelAttack();
				initiateJump(direction);
			else:
				velocity.x = move_toward(velocity.x, 0, SPEED / ATTACK_SLIDE_FACTOR)
		else:
			# In air, allow Dash Cancel Normals
			if curDashesinOneJump < MAX_DASHES_PER_JUMP && Input.is_action_just_pressed('light_punch') && Input.is_action_just_pressed('heavy_punch'):
				cancelAttack();
				initiateDash(direction, curDirection, ydirection)
	# PHase 3 - Check other inputs 
	elif Input.is_action_just_pressed("jump") && $AnimatedSprite2D.animation != 'flight':
		initiateJump(direction)
	elif Input.is_action_just_pressed("duck") and is_on_floor():
		curDashStopTime = DASH_STOP_TIME
		curDuckStopTime = DUCK_STOP_TIME		
		curDashSpeed = DASH_SPEED
		$AnimatedSprite2D.animation = 'duck'
		superJumpDownTimer = SUPER_JUMP_TIMING
	elif $AnimatedSprite2D.animation == "dash":
		# Let dash play out, or allow canceling
		processDashState(delta)
	# Process Normals
	elif curDashesinOneJump < MAX_DASHES_PER_JUMP && Input.is_action_just_pressed('light_punch') && Input.is_action_just_pressed('heavy_punch'):
		initiateDash(direction, curDirection, ydirection)
	elif Input.is_action_just_pressed('heavy_punch'):
		$AnimatedSprite2D.animation = 'heavy_punch'
		curAttackFrame = 0;
	elif Input.is_action_just_pressed('heavy_kick'):
		if is_on_floor():
			$AnimatedSprite2D.animation = 'heavy_kick'
		else:
			$AnimatedSprite2D.animation = 'heavy_kick_air'
		curAttackFrame = 0;
	elif Input.is_action_just_pressed('light_punch'):
		$AnimatedSprite2D.animation = 'light_punch'
		curAttackFrame = 0;
	elif Input.is_action_just_pressed('light_kick'):
		$AnimatedSprite2D.animation = 'light_kick'
		curAttackFrame = 0;
	elif Input.is_action_pressed('duck') and is_on_floor():
		$AnimatedSprite2D.animation = 'duck'
		curDuckStopTime -= delta
		if curDuckStopTime <= 0:
			velocity.x = 0
	elif $AnimatedSprite2D.animation == "run":
		# Let dash play out, or allow canceling
		processRunState(delta, curDirection)
	elif direction || (ydirection && $AnimatedSprite2D.animation == 'flight'):
		processDirectionHeld(direction, ydirection)
	else:
		processNoInput()
		
	lastDirection = curDirection
	
	if $AnimatedSprite2D.animation != "flight":
		move_and_slide()
	else:
		move_and_slide()
	
	
func initiateJump(direction):
	var collided = get_which_wall_collided()
	# handle jump from the ground
	if is_on_floor():
		$AnimatedSprite2D.animation = 'duck'
		if superJumpDownTimer > 0:
			isSuperJump = true
			velocity.y = SUPER_JUMP_VELOCITY
		else:
			isSuperJump = false
			velocity.y = JUMP_VELOCITY
	else:
		# Handle wall jump
		if is_on_wall() and curWallJumpsInOneJump < MAX_WALLJUMPS_PER_JUMP && direction == (-1 * collided):
			$AnimatedSprite2D.animation = 'duck'
			curWallJumpsInOneJump += 1
			curDashesinOneJump = 0
			curJumpsinOneJump = 0
			curWallClingsInOneJump = 0
			velocity.x = direction * SPEED;
			velocity.y = JUMP_VELOCITY			
			$AnimatedSprite2D.flip_h = direction == -1
		# Handle double jump next to wall
		elif is_on_wall() and curJumpsinOneJump < MAX_JUMPS_PER_JUMP && direction == (-1 * collided):
			$AnimatedSprite2D.animation = 'duck'
			velocity.y = JUMP_VELOCITY
			curJumpsinOneJump += 1
			velocity.x = direction * SPEED;
		# Handle double jump
		elif !is_on_wall() and curJumpsinOneJump < MAX_JUMPS_PER_JUMP:
			$AnimatedSprite2D.animation = 'duck'
			velocity.y = JUMP_VELOCITY
			curJumpsinOneJump += 1
			velocity.x = direction * SPEED;
			
	
func processDashState(delta):
#	if is_on_wall():
#		$AnimatedSprite2D.animation = 'duck'
#		endDash()
	if Input.is_action_just_pressed('heavy_punch'):
		$AnimatedSprite2D.animation = 'heavy_punch'
		endDash()
	elif Input.is_action_just_pressed('heavy_kick'):
		if is_on_floor():
			$AnimatedSprite2D.animation = 'heavy_kick'
		else:
			$AnimatedSprite2D.animation = 'heavy_kick_air'
		endDash()
	elif Input.is_action_just_pressed('light_punch'):
		$AnimatedSprite2D.animation = 'light_punch'
		endDash()
	elif Input.is_action_just_pressed('light_kick'):
		$AnimatedSprite2D.animation = 'light_kick'
		endDash()
	else:
		velocity.x = curXDirection * curDashSpeed
		velocity.y = curYDirection * curDashSpeed
		curDashStopTime -= delta
		curDashSpeed -= curDashSpeed * 0.04
		if curDashStopTime <= 0:
			$AnimatedSprite2D.animation = 'slide'
			endDash()
			
func processRunState(delta, curDirection):
	if is_on_wall():
		$AnimatedSprite2D.animation = 'fall'
		velocity.x = -1 * curDirection * SPEED;
	elif Input.is_action_just_pressed('duck'):
		$AnimatedSprite2D.animation = 'duck'
	elif Input.is_action_just_pressed('move_left') || Input.is_action_just_pressed('move_right'):
		$AnimatedSprite2D.animation = 'idle'
	elif Input.is_action_just_pressed('heavy_punch'):
		$AnimatedSprite2D.animation = 'heavy_punch'
	elif Input.is_action_just_pressed('heavy_kick'):
		$AnimatedSprite2D.animation = 'heavy_kick'
	elif Input.is_action_just_pressed('light_punch'):
		$AnimatedSprite2D.animation = 'light_punch'
	elif Input.is_action_just_pressed('light_kick'):
		$AnimatedSprite2D.animation = 'light_kick'
	else:
		velocity.x = RUN_SPEED * curDirection
		velocity.y = 0
			
func endDash():
	curDashStopTime = DASH_STOP_TIME
	curDashSpeed = DASH_SPEED

func processDirectionHeldFlight(direction, ydirection):
	velocity.x = direction * SPEED
	velocity.y = ydirection * SPEED

func processDirectionHeld(direction, ydirection):
	if $AnimatedSprite2D.animation == "flight":
		processDirectionHeldFlight(direction, ydirection)
		return
	
	var dashCheckDirection;
	if direction == 1:
		dashCheckDirection = "move_right"
	else:
		dashCheckDirection = "move_left"
	
	if is_on_floor() && Input.is_action_just_pressed(dashCheckDirection) and lastDirection == direction && curDoubleTapDashTime > 0:
		#initiateDash(direction, lastDirection, 0)
		$AnimatedSprite2D.animation = "run"
		return
	else:
		curDoubleTapDashTime = DOUBLE_TAP_DASH_TIME
		
	if is_on_floor():
		velocity.x = direction * SPEED
		if direction == -1:
			$AnimatedSprite2D.flip_h = true
		elif direction == 1:
			$AnimatedSprite2D.flip_h = false
		$AnimatedSprite2D.animation = "walk"
	else:
		if is_on_wall():
			if direction == lastDirection:
				if curWallClingsInOneJump < MAX_WALLCLING_PER_JUMP or $AnimatedSprite2D.animation == "wallcling":
					$AnimatedSprite2D.animation = "wallcling"
					if Input.is_action_just_pressed(dashCheckDirection):
						curWallSlideSpeed = -10
						curWallClingsInOneJump += 1
					else:
						curWallSlideSpeed += WALL_SLIDE_ACCELERATION
						if curWallSlideSpeed > MAX_WALL_SLIDE_SPEED:
							curWallSlideSpeed = MAX_WALL_SLIDE_SPEED
					velocity.x = 0
					if curWallSlideSpeed < 0:
						velocity.y = 0
					else:
						velocity.y = curWallSlideSpeed
			else:
				if Input.is_action_just_pressed(dashCheckDirection):
					initiateJump(direction)
		else:
			$AnimatedSprite2D.animation = "jump"
		#elif isSuperJump:
		velocity.x += direction * (SPEED / 30)
		if velocity.x > SPEED * 1.25:
			velocity.x = SPEED * 1.25;
		if velocity.x < -SPEED * 1.25:
			velocity.x = -SPEED * 1.25;
		

func processNoInput():
	if $AnimatedSprite2D.animation == "flight":
		velocity.x = 0
		velocity.y = 0
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED / SLIDE_FACTOR)
			if velocity.x == 0:
				$AnimatedSprite2D.animation = "idle"
			else:
				$AnimatedSprite2D.animation = "slide"
		else:
			$AnimatedSprite2D.animation = "jump"

func initiateDash(direction, curDirection, yDirection):
	curYDirection = yDirection
	curXDirection = direction
	var dashSpeedToUse
	if is_on_floor():
		dashSpeedToUse = DASH_SPEED
	else:
		if yDirection != 0:
			dashSpeedToUse = AIR_DASH_SPEED_VERTICAL
		else:
			dashSpeedToUse = AIR_DASH_SPEED_HORIZONTAL_ONLY
		curDashesinOneJump += 1
	curDashSpeed = dashSpeedToUse
	if direction:
		velocity.x = direction * dashSpeedToUse
		if direction == -1:
			$AnimatedSprite2D.flip_h = true
		elif direction == 1:
			$AnimatedSprite2D.flip_h = false
	
	if curYDirection:
		velocity.y = curYDirection * dashSpeedToUse
	else:
		velocity.y = 0
		
	if !direction && (!curYDirection || is_on_floor()):
		curXDirection = curDirection
		velocity.x = curDirection * dashSpeedToUse
		
	$AnimatedSprite2D.animation = "dash"

func _process(delta):
	pass

func activateHitBox(curDirection, position, size):
	$hitbox.set_position(Vector2(curDirection * position.x, position.y))
	$hitbox.shape_owner_get_owner(0).shape.set_size(size)

func disableHitBox():
	$hitbox.shape_owner_get_owner(0).shape.set_size(Vector2(0, 0))
	$hitbox.set_position(Vector2(-9999, -9999))

func _on_animated_sprite_2d_animation_finished():
	cancelAttack()
	if $AnimatedSprite2D.animation == "heavy_punch" || $AnimatedSprite2D.animation == "light_punch" || $AnimatedSprite2D.animation == "heavy_kick" || $AnimatedSprite2D.animation == "heavy_kick_air" || $AnimatedSprite2D.animation == "light_kick":
		if is_on_floor():
			$AnimatedSprite2D.animation = "idle"
		else:
			$AnimatedSprite2D.animation = "jump"
	if $AnimatedSprite2D.animation == "fall":
		$AnimatedSprite2D.animation = "duck"

func cancelAttack():
	curAttackFrame = 0;
	curAttackDetails = null
	curAttackHitOrBlocked = false
	disableHitBox()

func _on_animated_sprite_2d_frame_changed():
	if $AnimatedSprite2D.animation == "heavy_punch" || $AnimatedSprite2D.animation == "light_punch" || $AnimatedSprite2D.animation == "heavy_kick" || $AnimatedSprite2D.animation == "heavy_kick_air" || $AnimatedSprite2D.animation == "light_kick":
		curAttackFrame += 1


func _on_hitbox_body_entered(body):
	var curDirection = 1
	if $AnimatedSprite2D.flip_h:
		curDirection = -1;
	curAttackHitOrBlocked = true
	velocity.y *= 0.5
	body.takeDamage(self, curDirection, curAttackDetails)
	

func get_which_wall_collided():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision.get_normal().x > 0:
			return -1
		elif collision.get_normal().x < 0:
			return 1
	return 0
