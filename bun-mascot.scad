VARIANT = "default"; // ["default", "keychain"]

$fn = 180;

MAIN_RADIUS = 10;
CORE_HEIGHT = 17.5;

DEBUG = false;

numP = DEBUG ? 50 : 100;
deltaP = 1 / numP;
numTheta = DEBUG ? 90 : 180;
deltaTheta = 360 / numTheta;

// This prevents any following `CONSTANT_CASE` variables from being settable in the customizer.
// This prevents pathological interactions with persisted customizer values that are meant to be controlled exclusively by `VARIANT`.
/* [Hidden] */

VARIANT_DATA = [
  [
    "default",
    [
      [
        ["INCLUDE_KEYCHAIN_LOOP", false],
      ],
    ],
  ],
  [
    "keychain",
    [
      [
        ["INCLUDE_KEYCHAIN_LOOP", true],
      ],
    ],
  ],
];

include <./node_modules/scad/variants.scad>

INCLUDE_KEYCHAIN_LOOP = get_parameter("INCLUDE_KEYCHAIN_LOOP");

include <./node_modules/scad/vendor/BOSL2/std.scad>
include <./node_modules/scad/xyz.scad>
include <./node_modules/scad/filament_color.scad>
include <./node_modules/scad/duplicate.scad>
include <./node_modules/scad/compose.scad>

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
    MAIN_RADIUS * (semicircley(p) * smooth(p, [0.75, 1], [1, 0.75]) * smooth(p, [0.85, 1], [1, 0.75]) + smooth_and_back(p, [0.75, 0], [1, 0.05]) * smooth(th, [0, -3], [360, 1], scale_factor=20)),
    (th + smooth(p, [0.75, 0], [1, 45])),
    (pow(p, 1.25) + smooth(p, [0, 0.02], [0.05, 0]) - 0.02) * CORE_HEIGHT
  ) + _z_(smooth(p, [0.85, 0], [1, CORE_HEIGHT * 0.075]));

function a_to_p_th(a) = let (ij = a_to_ij(a), i = ij[0], j = ij[1]) [i * deltaP, j * deltaTheta];
function a_to_ij(a) = [a % (numP + 1), floor(a / (numP + 1))];
function ij_to_a(ij) = let (i = ij[0], j = ij[1]) i + (numP + 1) * j;

function pointy_a(a) = let (p_th = a_to_p_th(a), p = p_th[0], th = p_th[1]) pointy(p, th);

function b_to_ij(b) = [b % (numP), floor(b / (numP))];

function faces(b) =
  let (ij = b_to_ij(b), i = ij[0], j = ij[1]) [ij_to_a([i, j]), ij_to_a([i + 1, j]), ij_to_a([i + 1, j + 1]), ij_to_a([i, j + 1])];

module mouth() {
  translate(pointy(0.5, -90))
    difference() {
      scale([2.25, 4, 2.5])
        sphere(1);
      cuboid(100, anchor=BOTTOM);
    }
}

module scale_back(s) {
  scale([1, s, 1])
    intersection() {
      children();
      cuboid(100, anchor=FRONT);
    }
  difference() {
    children();
    cuboid(100, anchor=FRONT);
  }
}

INTEROCULAR_ANGLE = 35;

module main_eyes() {
  duplicate_and_rotate(rotation=[0, 0, INTEROCULAR_ANGLE])
    rotate([0, 0, -INTEROCULAR_ANGLE / 2])
      translate(pointy(0.61, -90))
        rotate([-25, 0, 0])
          scale([2, 0.25, 2]) scale_back(10) sphere(1);
}

module eye_pupils() {
  duplicate_and_rotate(rotation=[0, 0, INTEROCULAR_ANGLE])
    rotate([0, 0, -INTEROCULAR_ANGLE / 2])
      translate(pointy(0.61, -90))
        rotate([-25, 0, -5])
          translate([-0.35, -0.25, 0.35])
            scale([1, 0.125, 1]) scale_back(10) sphere(1);
}

color(FILAMENT_COLOR__BAMBU__PETG_HF__CREAM)
  compose() {
    // TODO: condense identical points at the ends?
    carvable() polyhedron(
        points=[for (a = [0:(numP + 1) * (numTheta + 1)]) pointy_a(a)],
        faces=[for (b = [0:( (numP) * numTheta) - 1]) faces(b)]
      );

    if (INCLUDE_KEYCHAIN_LOOP) {
      translate(pointy(0.65, 90)) {
        negative() sphere(3);
        positive() rotate([0, 90, 0])
            torus(or=5, ir=3);
      }
    }

    negative() mouth();
    negative() main_eyes();
  }

color(FILAMENT_COLOR__BAMBU__PLA_BASIC__BLACK) difference() {
    main_eyes();
    eye_pupils();
  }

color(FILAMENT_COLOR__BAMBU__PLA_BASIC__WHITE) eye_pupils();
