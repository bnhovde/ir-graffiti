/* ============================================================================
   Digital Graffiti Spray Can Enclosure  --  v2
   ----------------------------------------------------------------------------
   Changes vs v1:

     1) CAP is now three parts. The button plate can no longer be pushed down:
        it drops onto a solid internal shelf in cap_body and is clamped there
        by the plug on cap_top, which snaps into cap_body. Finger force goes
        disc -> shelf -> can, not into the disc's edges.

     2) BATTERY BOX is gone. The bottom cap now carries a slide-in cradle for
        the printed AAA_holder_di_CM.stl (dual AAA with cable management,
        36.2 x 56.5 x 12 mm) out of AAA_holder.3mf. Pull the bottom cap off and
        the loaded holder comes with it, open face outward, batteries fully
        accessible.

   PRINT ORIENTATION (no supports anywhere)
     body        : as modelled, upright, open end down.
     cap_body    : as modelled, rim up. The nozzle's 45 deg collar keeps it
                   support-free; only ~3 mm under the spout tip bridges.
     cap_top     : UPSIDE DOWN - roof flat on the bed, plug pointing up.
     button_disc : flat.
     bottom_cap  : as modelled, plate on the bed.

   LED AIM
     The LEDs fire radially, out a nozzle boss on the side of the cap - the way
     a real spray can sprays. Hold the can upright with your finger on the
     button and the nozzle toward the wall.

     NOTE, 30 Aug 2026: the original plan was for the IR to bounce off the wall
     and be seen by a camera at the back of the room. That was measured and is
     dead - roughly 1000x too dim. The camera now sits AT the wall looking back
     at the user, so the nozzle points straight at it and the camera sees the
     LEDs directly. The radial nozzle is still correct for that; only the camera
     moved. led_mode = "front" puts them out the top of the lid instead, "side"
     is v1's bare cross holes.

   ASSEMBLY
     To open either end: flat screwdriver into the slot at the seam, twist. Up
     top there is one, opposite the nozzle; at the bottom there are two,
     opposite each other, so you can walk the cap off level. In both cases the
     blade bears on the fixed part one way and the removable part the other.

     Push each LED down its nozzle channel from inside the wiring chamber until
     the dome is flush with the spout tip; leads run back into the chamber.
     Solder the switch to button_disc, drop the disc into cap_body onto the
     shelf (two flats key it), and bring the LED leads up through the disc's
     wire holes. Feed the battery wires up through the neck. Push cap_top on
     until it clicks. Load the AAA holder outside the can, slide it down into
     the cradle until it clicks past the two tabs, push the bottom cap home.
   ========================================================================== */

$fn = 96;

/* [What to render] */
// all | assembly | body | cap_body | cap_top | button_disc | bottom_cap
part = "all";

/* [Fit] */
fit    = 0.30;   // general sliding clearance - raise if parts bind
snap_r = 0.45;   // radial engagement of the cap_top snap bead

/* [Can] */
can_d   = 60;
can_h   = 120;
wall    = 2;
taper_h = 15;    // height of the shoulder cone

/* [Neck - where the cap grips] */
neck_d    = 18;
neck_h    = 10;
neck_bore = neck_d - 2*wall;   // 14 - wires pass through here
neck_bead = 0.35;              // radial snap bead (set 0 for plain friction)

/* [Cap] */
cap_od    = 36;
cap_wall  = 2;
roof_gap  = 0.6; // clearance over the switch body - keep > 0 or the roof holds
                 // the button permanently pressed. Also sets the plug depth.
roof_th   = 2;
disc_th   = 2.5;

/* [Tactile switch - 12x12 through hole] */
sw_body   = 12.4;  // body footprint - confirmed, fits canv1's square pocket
sw_body_h = 3.5;   // body height above the disc            (datasheet)
sw_stem_h = 1.5;   // plunger height above the body. Reference only - nothing is
                   // derived from it. roof_gap guarantees the roof never touches
                   // the switch, and the plunger is reached through sw_hole_d
                   // whether it ends up proud of the roof or a little recessed.
sw_hole_d = 8.0;   // finger hole in the roof, same as canv1
sw_pin_x  = 12.5;  // confirmed, legs fit canv1's disc
sw_pin_y  = 4.5;   // (datasheet)
sw_pin_d  = 2.0;

/* [IR LEDs] */
led_body_d = 3.0;       // set 5.0 if you got 5 mm LEDs
led_n      = 2;
led_mode   = "nozzle";  // "nozzle" = radial, out a nozzle boss on the side of the
                        //            cap, the way a real spray can sprays
                        // "front"  = axial, out the top of the lid
                        // "side"   = v1 behaviour, bare cross holes
led_offset = 9.5;       // "front" mode only: radius either side of the button
nozzle_out = 4.0;       // how far the nozzle spout stands proud of the cap

/* [Pry slots - for getting the caps back off] */
pry_w     = 9.0;         // tangential width, both ends
pry_h     = 1.2;         // pocket height, both ends
pry_d     = 1.5;         // top: radial depth (cap wall there is 2.0, 0.5 left)
pry_a     = 180;         // top: which way it faces - 180 = opposite the nozzle
pry_d_bot = 1.8;         // bottom: depth. Must stay under can_d/2 - bplug_od/2
                         // or it undercuts the root of the plug ring.
pry_a_bot = [0, 180];    // bottom: two, so you can walk the cap off evenly

/* [Battery holder pocket - AAA_holder_di_CM.stl out of AAA_holder.3mf]
   Variants in that 3mf, W x L x T:
     AAA_holder_di.stl      29.80 x 56.5 x 12   (no cable management)
     AAA_holder_di_CM.stl   36.20 x 56.5 x 12   <- this one
   On the CM part the extra width is cable-management wings on the back half of
   the thickness only; the battery face is still 29.8 wide. The pocket is cut to
   the full 36.2 so the wings are what the side rails grip, and `lip` is set deep
   enough that the front lips still catch the narrower battery face. */
hold_w   = 36.20;
hold_t   = 12.0;
hold_l   = 56.5;
hold_fit = 0.50;

/* [Bottom cap] */
base_th = 3.0;   // 1.2 of this is the pry pocket, so keep it >= 2.8
base_od = can_d; // set this 2 mm over can_d for a proud foot ring you can get a
                 // blade under anywhere, instead of / as well as the pry slots
bplug_h = 7;
bsnap_r = 0.40;

/* ---------------------------------------------------------------- derived */
can_bore   = can_d - 2*wall;         // 56
shelf_gap  = led_body_d + 3;         // clear space under the disc. In nozzle mode
                                     // this chamber is what the LEDs lie in, so
                                     // it scales with the LED.
cap_bore   = cap_od - 2*cap_wall;    // 32
skirt_bore = neck_d + fit;           // 18.3
skirt_z    = neck_h + 0.5;           // cap seats on the shoulder, not the neck
chamber_d  = cap_bore - 6;           // 26 - wiring space under the disc
shelf_z    = neck_h + shelf_gap;     // 15 - top face of the shelf
disc_d     = cap_bore - fit;         // 31.7
disc_z1    = shelf_z + disc_th;      // 17.5
plug_h     = sw_body_h + roof_gap;   // roof underside sits just clear of the switch
cap_body_h = disc_z1 + plug_h;       // 21.6
plug_od    = cap_bore - fit;
plug_bore  = plug_od - 2*cap_wall;   // 27.7
roof_z0    = cap_body_h;
roof_z1    = roof_z0 + roof_th;      // 23.6
bead_od    = cap_bore + 2*snap_r;
bead_ramp  = (bead_od - plug_od)/2;  // 45 deg both sides -> printable, no support
bead_z     = disc_z1 + plug_h/2;     // bead centre

rail_w = 4.0;    // tangential width of the keying rails
rail_p = 1.5;    // how far they poke into the bore

led_hole_d = led_body_d + 0.2;   // press fit - LED slides down its channel
led_pass_d = led_body_d + 0.6;   // clearance in the disc ("front" mode)

// --- nozzle boss. Sits at the chamber level, below the disc, so the whole
//     thing lives in cap_body: no channel has to cross the cap_top joint.
nozzle_z      = (skirt_z + shelf_z)/2;
led_pitch     = led_body_d + 1.0;
nozzle_tip_d  = (led_n-1)*led_pitch + led_body_d + 2.6;   // spout diameter
nozzle_col_d  = nozzle_tip_d + 8;                         // collar at the wall
nozzle_col_l  = (nozzle_col_d - nozzle_tip_d)/2;          // 45 deg -> no support
// sink the collar just far enough that its rim is inside the cap's curve
nozzle_y0     = sqrt(pow(cap_od/2,2) - pow(nozzle_col_d/2,2)) - 0.5;
nozzle_len    = cap_od/2 + nozzle_out - nozzle_y0;

shoulder_z = can_h + taper_h;    // flat annulus the cap rim lands on
neck_top   = shoulder_z + neck_h;

/* ================================================================== 1. BODY */
module body() {
    difference() {
        union() {
            cylinder(h=can_h, d=can_d);
            translate([0,0,can_h]) cylinder(h=taper_h, d1=can_d, d2=cap_od);
            translate([0,0,shoulder_z]) cylinder(h=neck_h, d=neck_d);

            // snap bead on the neck, double 45 deg so it needs no support
            if (neck_bead > 0)
                translate([0,0,neck_top - 3.5 - neck_bead]) {
                    cylinder(h=neck_bead, d1=neck_d, d2=neck_d + 2*neck_bead);
                    translate([0,0,neck_bead])
                        cylinder(h=neck_bead, d1=neck_d + 2*neck_bead, d2=neck_d);
                }
        }

        // ---- interior. The taper's inner cone runs straight to the neck bore
        //      so there is no unsupported ceiling ring under the shoulder.
        translate([0,0,-1]) cylinder(h=can_h+1, d=can_bore);
        translate([0,0,can_h]) cylinder(h=taper_h+0.01, d1=can_bore, d2=neck_bore);
        translate([0,0,shoulder_z-0.01]) cylinder(h=neck_h+2, d=neck_bore);

        // ---- groove for the bottom cap snap (centre at z = 3.0)
        translate([0,0,3.0-bsnap_r])
            cylinder(h=bsnap_r, d1=can_bore, d2=can_bore + 2*bsnap_r + 0.2);
        translate([0,0,3.0])
            cylinder(h=bsnap_r, d1=can_bore + 2*bsnap_r + 0.2, d2=can_bore);

        // ---- slits so the neck can flex over its bead
        if (neck_bead > 0)
            for (a=[45:90:315]) rotate([0,0,a])
                translate([-0.9, neck_bore/2 - 1, neck_top-7])
                    cube([1.8, (neck_d - neck_bore)/2 + 2, 7.5]);

        // ---- lead-in chamfer on the open bottom
        translate([0,0,-0.01]) cylinder(h=1.2, d1=can_bore+1.6, d2=can_bore);
    }
}

/* ============================================================= 2. CAP BODY */
module cap_body() {
    union() {
        difference() {
            union() {
                cylinder(h=cap_body_h, d=cap_od);
                if (led_mode == "nozzle")
                    intersection() {
                        nozzle_boss();
                        cylinder(h=cap_body_h, d=cap_od + 2*nozzle_out + 2);
                    }
            }

            // skirt that grips the can neck
            translate([0,0,-0.01]) cylinder(h=skirt_z+0.01, d=skirt_bore);
            translate([0,0,-0.01]) cylinder(h=1.2, d1=skirt_bore+2.0, d2=skirt_bore);

            // groove for the neck bead
            if (neck_bead > 0) {
                translate([0,0,neck_top - 3.5 - neck_bead - shoulder_z])
                    cylinder(h=neck_bead, d1=skirt_bore, d2=skirt_bore+2*neck_bead+0.2);
                translate([0,0,neck_top - 3.5 - shoulder_z])
                    cylinder(h=neck_bead, d1=skirt_bore+2*neck_bead+0.2, d2=skirt_bore);
            }

            // wiring chamber, then the shelf, then the main bore
            translate([0,0,skirt_z])
                cylinder(h=shelf_z-skirt_z+0.01, d=chamber_d);
            translate([0,0,shelf_z])
                cylinder(h=cap_body_h-shelf_z+1, d=cap_bore);

            // snap groove for cap_top
            translate([0,0,bead_z-bead_ramp])
                cylinder(h=bead_ramp, d1=cap_bore, d2=bead_od+0.15);
            translate([0,0,bead_z])
                cylinder(h=bead_ramp, d1=bead_od+0.15, d2=cap_bore);

            // pry pocket: roofed by the cap_top flange, floored by the rim, so a
            // flat blade twisted in it levers the two apart
            rotate([0,0,pry_a])
                translate([-pry_w/2, cap_od/2 - pry_d, cap_body_h - pry_h])
                    cube([pry_w, pry_d + 1, pry_h + 0.01]);

            // LED channels, drilled radially out through the nozzle
            if (led_mode == "nozzle") led_channels();
            if (led_mode == "side") side_led_holes((disc_z1 + cap_body_h)/2);
        }

        // keying rails, added after the bores so they survive
        for (s=[-1,1])
            translate([s == 1 ? cap_bore/2 - rail_p : -cap_bore/2,
                       -rail_w/2, shelf_z])
                cube([rail_p, rail_w, cap_body_h - shelf_z]);
    }
}

/* ============================================================== 3. CAP TOP */
module cap_top() {
    difference() {
        union() {
            translate([0,0,roof_z0]) cylinder(h=roof_th, d=cap_od);   // roof/flange
            translate([0,0,disc_z1]) cylinder(h=plug_h, d=plug_od);   // plug
            translate([0,0,bead_z-bead_ramp])                         // snap bead
                cylinder(h=bead_ramp, d1=plug_od, d2=bead_od);
            translate([0,0,bead_z])
                cylinder(h=bead_ramp, d1=bead_od, d2=plug_od);
        }

        translate([0,0,disc_z1-0.01]) cylinder(h=plug_h+0.02, d=plug_bore);

        // actuator hole
        translate([0,0,roof_z0-0.01]) cylinder(h=roof_th+0.02, d=sw_hole_d);

        // LED holes
        if (led_mode == "front")
            for (s=[-1,1])
                translate([0, s*led_offset, roof_z0-0.01])
                    cylinder(h=roof_th+0.02, d=led_hole_d);
        if (led_mode == "side") side_led_holes((roof_z0+roof_z1)/2);

        // slots for the cap_body rails - also stops the top rotating
        for (s=[-1,1])
            translate([s*(plug_od/2), 0, disc_z1 + plug_h/2])
                cube([2*rail_p+0.8, rail_w+0.5, plug_h+0.02], center=true);

        // split the plug into a springy collet so the snap is easy to work
        for (a=[45:90:315]) rotate([0,0,a])
            translate([-0.75, 0, disc_z1-0.01])
                cube([1.5, plug_od, plug_h-1.2]);

        // 45 deg lead-in on the flange edge above the pry pocket, so the blade
        // has a mouth to enter and you can see where the slot is
        rotate([0,0,pry_a])
            translate([0, cap_od/2, roof_z0])
                rotate([45,0,0]) cube([pry_w, 1.13, 1.13], center=true);
    }
}

/* Nozzle boss on the +Y side of the cap: a spout with a 45 deg collar where it
   meets the wall, so the only overhang is the last few mm under the spout tip,
   which bridges fine when cap_body is printed rim up. */
module nozzle_boss() {
    translate([0, nozzle_y0, nozzle_z]) rotate([-90,0,0]) {
        cylinder(h=nozzle_len,   d=nozzle_tip_d);                       // spout
        cylinder(h=nozzle_col_l, d1=nozzle_col_d, d2=nozzle_tip_d);     // collar
    }
}

/* One bore per LED, from the wiring chamber straight out through the nozzle
   face. Push each LED down its channel until the dome is flush with the tip. */
module led_channels() {
    for (i = [0 : led_n-1])
        translate([(i - (led_n-1)/2) * led_pitch, 0, nozzle_z])
            rotate([-90,0,0])
                cylinder(h = cap_od/2 + nozzle_out + 1, d = led_hole_d);
}

/* v1-style cross holes, kept as an option via led_mode = "side" */
module side_led_holes(z) {
    for (s=[-1,1])
        translate([-cap_od, s*6, z])
            rotate([0,90,0]) cylinder(h=2*cap_od, d=led_hole_d);
}

/* =========================================================== 4. BUTTON DISC */
module button_disc() {
    difference() {
        union() {
            cylinder(h=disc_th, d=disc_d);
            // four posts that nest the switch body
            for (a=[0:90:270]) rotate([0,0,a])
                translate([sw_body/2 + 0.25, -1.6, 0])
                    cube([1.4, 3.2, disc_th + 1.2]);
        }

        for (x=[-1,1], y=[-1,1])                       // switch pins
            translate([x*sw_pin_x/2, y*sw_pin_y/2, -1])
                cylinder(h=disc_th+2, d=sw_pin_d);

        if (led_mode == "front")                       // LED bodies / leads
            for (s=[-1,1])
                translate([0, s*led_offset, -1])
                    cylinder(h=disc_th+2, d=led_pass_d);

        for (s=[-1,1])                                 // keying flats
            translate([s*(disc_d/2), 0, disc_th/2])
                cube([2*rail_p+0.6, rail_w+0.4, disc_th+2], center=true);

        for (a=[45:90:315]) rotate([0,0,a])            // wire pass-throughs
            translate([11.5, 0, -1]) cylinder(h=disc_th+2, d=3.0);
    }
}

/* ===================================== 5. BOTTOM CAP + BATTERY HOLDER CRADLE */
cw      = hold_w + hold_fit;   // pocket X
ct      = hold_t + hold_fit;   // pocket Y
rail_t  = 2.5;                 // side rail thickness
back_t  = 2.5;
front_t = 2.0;
lip     = 6.0;                 // how far the front lips wrap in. Must reach past
                               // hold_w/2 - 14.9 to catch the CM part's narrower
                               // battery face, not just the wings.

// Retention catch. This sits on the FRONT lips, not the side rails, and the
// reason is the CM holder's cable-management wings: eight discrete lugs that
// stick out to |x| = 18.10 along the BACK half of the thickness. Anything
// biting inward from the side rails has to be forced past all eight. The front
// half of the holder never exceeds 14.90 wide and the wings never reach the
// front, so a catch here leaves the whole wing corridor clear.
catch_p = 0.8;                 // how far it stands into the pocket, in -Y
catch_h = 1.6;                 // flat catching face
catch_w = 3.6;                 // tangential width, measured in from the window
catch_lead = 3.0;              // 45-ish deg lead-in above it
crad_z0 = base_th;             // pocket floor
crad_h  = hold_l + 6;

bplug_od = can_bore - fit;
bplug_id = bplug_od - 4;

module cradle() {
    y0 = -(ct/2 + back_t);
    union() {
        difference() {
            translate([-(cw/2 + rail_t), y0, crad_z0])
                cube([cw + 2*rail_t, back_t + ct + front_t, crad_h]);

            // the pocket, open at the top
            translate([-cw/2, -ct/2, crad_z0]) cube([cw, ct, crad_h+2]);

            // flared lead-in at the mouth
            hull() {
                translate([-cw/2, -ct/2, crad_z0+crad_h-2]) cube([cw, ct, 0.01]);
                translate([-cw/2-1.4, -ct/2-1.4, crad_z0+crad_h])
                    cube([cw+2.8, ct+2.8, 0.01]);
            }

            // front window - this is the face the batteries drop into
            translate([-(cw/2 - lip), ct/2 - 0.01, crad_z0-1])
                cube([cw - 2*lip, front_t + 1, crad_h+3]);

            // back window - saves plastic and lets the leads out
            translate([-cw/4, y0-0.5, crad_z0+7])
                cube([cw/2, back_t+1, hold_l-14]);
        }

        // retention catches on the front lips: flat face underneath, lead-in
        // above. The holder's front face clicks past them; the wings pass
        // behind, untouched.
        for (s=[-1,1])
            hull() {
                translate([s > 0 ? cw/2 - lip : -(cw/2 - lip) - catch_w,
                           ct/2 - catch_p, crad_z0 + hold_l])
                    cube([catch_w, catch_p, catch_h]);
                translate([s > 0 ? cw/2 - lip : -(cw/2 - lip) - catch_w,
                           ct/2 - 0.01, crad_z0 + hold_l + catch_lead])
                    cube([catch_w, 0.01, 0.01]);
            }
    }
}

// removes the outer bottom edge of a d-diameter part at 45 deg
module edge_chamfer(d, c) {
    rotate_extrude(convexity=4)
        polygon([[d/2-c, -0.01], [d/2+2, -0.01], [d/2+2, c], [d/2, c]]);
}

module bottom_cap() {
    union() {
        difference() {
            union() {
                cylinder(h=base_th, d=base_od);
                translate([0,0,base_th]) cylinder(h=bplug_h, d=bplug_od);
                // snap bead, double 45 deg
                translate([0,0,base_th+3.0-bsnap_r])
                    cylinder(h=bsnap_r, d1=bplug_od, d2=can_bore+2*bsnap_r);
                translate([0,0,base_th+3.0])
                    cylinder(h=bsnap_r, d1=can_bore+2*bsnap_r, d2=bplug_od);
            }

            translate([0,0,base_th]) cylinder(h=bplug_h+1, d=bplug_id);

            // pry pockets: bitten down into the base plate at the seam, so the
            // can's own bottom rim roofs them. No alignment needed - the rim is
            // a full circle, so the cap can go in at any rotation.
            for (a = pry_a_bot) rotate([0,0,a])
                translate([-pry_w/2, base_od/2 - pry_d_bot, base_th - pry_h])
                    cube([pry_w, pry_d_bot + 1, pry_h + 0.01]);

            // slits so the ring can flex - kept out at the rim, clear of the cradle
            for (a=[0:60:359]) rotate([0,0,a])
                translate([-1.25, bplug_id/2 - 2, base_th + bplug_h - 5.5])
                    cube([2.5, 6, 6]);

            edge_chamfer(base_od, 1.0);
        }
        cradle();
    }
}

/* ============================================================ 6. RENDERING */
module layout_all() {
    body();
    translate([can_d + 25, 0, 0]) bottom_cap();
    translate([-(can_d/2 + cap_od/2 + 15), 0, 0]) cap_body();
    translate([-(can_d/2 + cap_od/2 + 15), cap_od + 12, -disc_z1]) cap_top();
    translate([-(can_d/2 + cap_od/2 + 15), -(cap_od + 12), 0]) button_disc();
}

module layout_assembly() {
    body();
    translate([0,0,shoulder_z]) {
        cap_body();
        translate([0,0,shelf_z]) button_disc();
        cap_top();
    }
    translate([0,0,-base_th]) bottom_cap();
}

if      (part == "all")         layout_all();
else if (part == "assembly")    layout_assembly();
else if (part == "body")        body();
else if (part == "cap_body")    cap_body();
else if (part == "cap_top")     translate([0,0,-disc_z1]) cap_top();
else if (part == "button_disc") button_disc();
else if (part == "bottom_cap")  bottom_cap();
else if (part != "none")        layout_all();
