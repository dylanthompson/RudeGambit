extends RigidBody2D


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func takeDamage(hitter, direction, attackDetails):
	$AnimatedSprite2D.animation = 'hit'
	$AnimatedSprite2D.play()
	print("Damage taken from ", hitter)
	self.apply_central_force(Vector2(attackDetails['knockback'].x * direction, attackDetails['knockback'].y))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_animated_sprite_2d_animation_finished():
	if $AnimatedSprite2D.animation == 'hit':
		$AnimatedSprite2D.animation = 'idle'
		pass # Replace with function body.
