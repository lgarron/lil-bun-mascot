include <./node_modules/scad/vendor/BOSL2/std.scad>
include <./node_modules/scad/xyz.scad>

MAIN_RADIUS = 20;
CORE_HEIGHT = 30;

numP = 100;
deltaP = 1 / numP;
numTheta = 180;
deltaTheta = 360 / numTheta;

// This prevents any following `CONSTANT_CASE` variables from being settable in the customizer.
// This prevents pathological interactions with persisted customizer values that are meant to be controlled exclusively by `VARIANT`.
/* [Hidden] */

assert(360 % numTheta == 0);

function pol(r, th, z) = [cos(th) * r, sin(th) * r, z];
function semicircley(p) = sqrt(1 - pow(1 - 2 * p, 2));
function smooth_semicircle_uv(p) = (sin((p / 2 - 1 / 4) * 360) + 1) / 2;
function pointy(p, th) = point(smooth_semicircle_uv(p), th);

function smooth(p, xy1, xy2, scale_factor = 1) =
  p < xy1.x ? xy1.y
  : (
    p > xy2.x ? xy2.y
    : (
      xy1.y + smooth_semicircle_uv((p - xy1.x) / (xy2.x - xy1.x) * scale_factor) * (xy2.y - xy1.y)
    )
  );

function smooth_and_back(p, xy1, xy2) =
  smooth(p, xy1, xy2, scale_factor=2);

function point(p, th) =
  pol(
    MAIN_RADIUS * (semicircley(p) * smooth(p, [0.75, 1], [1, 0.75]) * smooth(p, [0.85, 1], [1, 0.75]) + smooth_and_back(p, [0.75, 0], [1, 0.05]) * smooth(th, [0, -2], [360, 1], scale_factor=20)),
    (th + smooth(p, [0.75, 0], [1, 45])),
    pow(p, 1.15) * CORE_HEIGHT
  ) + _z_(smooth(p, [0.85, 0], [1, 0.1]));

for (v = [0:deltaP:1 - deltaP]) {

  for (th = [0:deltaTheta:360 - deltaTheta]) {
    polyhedron(
      points=[
        pointy(v, th),
        pointy(v, th + deltaTheta),
        pointy(v + deltaP, th + deltaTheta),
        pointy(v + deltaP, th),
      ],
      faces=[
        [0, 1, 2, 3],
      ]
    );
  }
}
