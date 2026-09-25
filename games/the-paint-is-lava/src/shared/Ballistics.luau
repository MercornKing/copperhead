--!strict
--[[
	Ballistics: pure maths shared by the server simulation and client visuals, so a paint
	blob drawn on screen follows the same arc the server uses to decide where it lands.
]]

local Ballistics = {}

local GRAVITY_DIR = Vector3.new(0, -1, 0)

-- Random direction inside a cone of half-angle `spreadDegrees` around `direction`.
-- `rand` returns uniform [0, 1); pass math.random or a seeded Random's NextNumber.
function Ballistics.Spread(direction: Vector3, spreadDegrees: number, rand: () -> number): Vector3
	local dir = direction.Unit
	if spreadDegrees <= 0 then
		return dir
	end
	local maxAngle = math.rad(spreadDegrees)
	-- Uniform over the spherical cap.
	local cosAngle = 1 - rand() * (1 - math.cos(maxAngle))
	local sinAngle = math.sqrt(1 - cosAngle * cosAngle)
	local roll = rand() * 2 * math.pi

	local helper = if math.abs(dir.Y) < 0.99 then Vector3.new(0, 1, 0) else Vector3.new(1, 0, 0)
	local right = dir:Cross(helper).Unit
	local up = right:Cross(dir).Unit
	return (dir * cosAngle + (right * math.cos(roll) + up * math.sin(roll)) * sinAngle).Unit
end

-- Advance a projectile by dt. Semi-implicit Euler: stable and cheap.
function Ballistics.Step(position: Vector3, velocity: Vector3, gravity: number, dt: number): (Vector3, Vector3)
	local newVelocity = velocity + GRAVITY_DIR * gravity * dt
	return position + newVelocity * dt, newVelocity
end

-- Splash damage at `distance` from the burst centre. Full at the centre, 40% at the edge,
-- none beyond. PLACEHOLDER curve: tune alongside SplashRadius per weapon.
function Ballistics.SplashDamage(maxDamage: number, radius: number, distance: number): number
	if radius <= 0 or distance > radius then
		return 0
	end
	return maxDamage * (1 - 0.6 * (distance / radius))
end

-- Reflect a velocity off a surface normal, keeping `bounciness` of its speed.
function Ballistics.Bounce(velocity: Vector3, normal: Vector3, bounciness: number): Vector3
	local n = normal.Unit
	return (velocity - n * 2 * velocity:Dot(n)) * bounciness
end

return Ballistics
