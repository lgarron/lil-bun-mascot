VARIANT = "default"; // ["default", "keychain", "eyes-only", "cheeks-only", "mouth-only"]

$fn = 180;

MAIN_RADIUS = 10;
CORE_HEIGHT = 17.5;

DEBUG = false;
REDUCE_MESH_DENSITY_FOR_DEBUG = true;

numP = (DEBUG && REDUCE_MESH_DENSITY_FOR_DEBUG) ? 50 : 100;
deltaP = 1 / numP;
numTheta = (DEBUG && REDUCE_MESH_DENSITY_FOR_DEBUG) ? 90 : 180;
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
        ["EYES_ONLY", false],
        ["CHEEKS_ONLY", false],
        ["MOUTH_ONLY", false],
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
  [
    "eyes-only",
    [
      [
        ["EYES_ONLY", true],
      ],
    ],
  ],
  [
    "cheeks-only",
    [
      [
        ["CHEEKS_ONLY", true],
      ],
    ],
  ],
  [
    "mouth-only",
    [
      [
        ["MOUTH_ONLY", true],
      ],
    ],
  ],
];

include <./node_modules/scad/variants.scad>

INCLUDE_KEYCHAIN_LOOP = get_parameter("INCLUDE_KEYCHAIN_LOOP");
EYES_ONLY = get_parameter("EYES_ONLY");
CHEEKS_ONLY = get_parameter("CHEEKS_ONLY");
MOUTH_ONLY = get_parameter("MOUTH_ONLY");
ONLY = EYES_ONLY ? "eyes" : (CHEEKS_ONLY ? "cheeks" : (MOUTH_ONLY ? "mouth" : undef));

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

MOUTH_TRANSLATION = pointy(0.5, -90);

module mincore(sc = 1, shave_top = 0) {
  translate(MOUTH_TRANSLATION)
    difference() {
      scale(sc)
        scale([1.8, 4, 2.5])
          sphere(1);
      down(shave_top)
        cuboid(100, anchor=BOTTOM);
    }
}
module mouth_negative() {
  minkowski() {
    mincore()
      rotate([90, 0, 0])
        cyl(r=0.1, h=1);
  }
}

MOUTH_COLOR_INSET = 1;

module mouth_color() {
  color(FILAMENT_COLOR__BAMBU__PLA_BASIC__RED)
    difference() {
      mincore();
      mincore(0.8, shave_top=0.3);
      back(MOUTH_COLOR_INSET)
        translate(MOUTH_TRANSLATION)
          cuboid(1000, anchor=BACK);
    }
}

if (ONLY == "mouth") {
  translate([MAIN_RADIUS, -10, 0])
    down(MOUTH_COLOR_INSET)
      rotate([90, 0, 0])
        translate(-MOUTH_TRANSLATION)
          mouth_color();
}

if (DEBUG) {
  mouth_color();
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

INTEROCULAR_ANGLE = 50;
EXTRA_ANGLE_CHEEKS = 10;

module eyeify(extra_angle = 0, p = 0.61, vertical_angle = -20, double = true, index = 0) {
  angle = INTEROCULAR_ANGLE + extra_angle;
  rotate([0, 0, index == 1 ? angle : 0])
    duplicate_and_rotate(rotation=[0, 0, angle], number_of_total_copies=double ? 2 : 1)
      rotate([0, 0, -angle / 2])
        translate(pointy(p, -90))
          rotate([vertical_angle, 0, 0]) translate([0, 0.1, 0])
              children();
}

module uneyeify(extra_angle = 0, p = 0.61, vertical_angle = -20, index = 0) {
  angle = INTEROCULAR_ANGLE + extra_angle;
  rotate([90, 0, 0])
    translate([0, -0.1, 0])
      rotate([-vertical_angle, 0, 0])
        translate(-pointy(p, -90))
          rotate([0, 0, angle / 2])
            rotate([0, 0, index == 1 ? -angle : 0])
              children();
}

module eye_outer(epsilon = 0, clearance = 0, extra_inset = 0) {
  translate([0, -epsilon, 0])
    rotate([-90, 0, 0]) {
      cylinder(r=2 - clearance, h=2.2 + extra_inset + epsilon, anchor=BOTTOM);
      scale([1.25, 0.75, 1])
        cylinder(r=1 - clearance, h=3.5 + extra_inset + epsilon, anchor=BOTTOM);
    }
}

module eye_inner(epsilon = 0, clearance = 0, extra_inset = 0) {
  translate([-0.25, -epsilon, 0.25])
    rotate([-90, 0, 0])
      cylinder(r=1.25 - clearance, h=0.2 + extra_inset + epsilon, anchor=BOTTOM);
}

module cheek(epsilon = 0, clearance = 0, extra_inset = 0) {
  translate([-0.25, -epsilon, 0.25])
    rotate([-90, 0, 0])
      scale([1.5, 1, 1])
        cylinder(r=1.25 - clearance, h=2 + extra_inset + epsilon, anchor=BOTTOM);
}

module cheekify(double = true, index = 0) {
  eyeify(10, 0.52, -5, double=double, index=index) children();
}

module uncheekify(index = 0) {
  uneyeify(10, 0.52, -5, index=index) children();
}

if (DEBUG) {
  color(FILAMENT_COLOR__BAMBU__PLA_BASIC__BLACK)
    eyeify()
      difference() {
        eye_outer(epsilon=0);
        eye_inner(epsilon=1);
      }

  color(FILAMENT_COLOR__BAMBU__PLA_BASIC__WHITE)
    eyeify() eye_inner();

  
  color(FILAMENT_COLOR__ELEGOO__PLA_PLUS__PINK)
    difference() {
      cheekify() cheek();
      eyeify() eye_outer(epsilon=1);
    }
}

if (ONLY == "eyes")
  duplicate_and_translate([5, 0, 0])
    color(FILAMENT_COLOR__BAMBU__PLA_BASIC__WHITE)
      right(MAIN_RADIUS)
        rotate([90, 0, 0])
          difference() {
            eye_outer(epsilon=0, clearance=0.1);
            eye_inner(epsilon=1);
          }

if (ONLY == "eyes")
  duplicate_and_translate([5, 0, 0])
    color(FILAMENT_COLOR__BAMBU__PLA_BASIC__BLACK)
      right(MAIN_RADIUS)
        rotate([90, 0, 0])
          eye_inner();

if (ONLY == "cheeks")
  color(FILAMENT_COLOR__ELEGOO__PLA_PLUS__PINK)
    translate([MAIN_RADIUS, 10, 0])
      uncheekify(index=0)
        difference() {
          cheekify(double=false, index=0) cheek();
          eyeify() eye_outer(epsilon=1);
        }

if (ONLY == "cheeks")
  color(FILAMENT_COLOR__ELEGOO__PLA_PLUS__PINK)
    translate([MAIN_RADIUS + 5, 10, 0])
      uncheekify(index=1)
        difference() {
          cheekify(double=false, index=1) cheek();
          eyeify() eye_outer(epsilon=1);
        }

module main_shape() {
  // TODO: condense identical points at the ends?
  polyhedron(
    points=[for (a = [0:(numP + 1) * (numTheta + 1)]) pointy_a(a)],
    faces=[for (b = [0:( (numP) * numTheta) - 1]) faces(b)]
  );
}

if (is_undef(ONLY))
  color(FILAMENT_COLOR__BAMBU__PETG_HF__CREAM)
    compose() {
      carvable() main_shape();

      if (INCLUDE_KEYCHAIN_LOOP) {
        translate(pointy(0.525, 90)) {
          negative() rotate([0, 00, 0]) {
              torus(or=5, ir=2);
              scale([1.25, 1, 1])
                torus(or=5, ir=2);
            }
        }
      }

      negative()
        eyeify() eye_outer(extra_inset=0.3, epsilon=1);
      negative()
        cheekify() cheek(extra_inset=0.3, epsilon=1);
      negative() mouth_negative();
    }
