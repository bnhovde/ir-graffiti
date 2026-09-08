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
     LEDs directly, so the radial nozzle is still correct; only the camera
     moved.

     NOTE, 8 Sep 2026: the pair of 3 mm 940 nm indicators is gone, replaced by
     a single 8 mm 3 W 850 nm emitter with a 120 degree beam. Measured on both
     a Mac at 16 ms auto exposure and a Pi at 2 ms manual, the old LEDs held
     lock only within about +/-20 degrees - the same cone in two sensitivity
     regimes an order of magnitude apart, which says the limit was the beam,
     not the signal. The "front" and "side" LED modes went with them.

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

/* [IR LED - one 8 mm 3 W emitter, 850 nm, 120 degree]
   Radial, out a nozzle boss on the side of the cap, the way a real spray can
   sprays - which is also straight at the camera, since the camera sits at the
   screen looking back at the user.
   From the drawing: body 8.0 round (7.2 across the flats), dome / die disc 6.0,
   thermal slug 6.2 underneath, tabs 1.5 wide x 1.05 thick spanning 14.5 tip to
   tip, dome 2.6 proud of the body top face. The 120 deg part is 5.0 tall
   overall, so the body itself is 2.4. The 60/90 deg parts in the same family
   are 5.9 - the pocket seats on the body TOP face, so the dome lands in the
   same place whichever one you have and only the tail gets longer. */
nozzle_out    = 4.0;    // how far the nozzle spout stands proud of the cap
pled_body_d   = 8.0;
pled_dome_d   = 6.0;
pled_dome_h   = 2.6;
pled_body_h   = 3.65;   // measured. Sets how deep the bore runs, and so how
                        // much of the LED ends up inside the nozzle.
pled_tab_w    = 1.5;    // tab width, across the slot (the 1.05 thickness runs
                        // along the bore, where the slot is long anyway)
pled_tab_stag = 1.5;    // THE TABS ARE STAGGERED, not opposite each other: one
                        // leaves high, the other low. The slot has to swallow
                        // both, so it is tab width + this. Generous on purpose
                        // - it is read off a drawing, and a slot that is too
                        // tall only lets the LED rock a little inside a bore
                        // that already holds it over 3.65 mm of its length.
                        // Keeping it symmetric also means the part goes in
                        // either way up.
pled_tab_span = 14.5;   // FULL, untrimmed. The tabs are the retention: they
                        // cannot pass the 8.2 bore, so they bear on the ring
                        // behind it and hold the LED in. That is why nothing
                        // sits in front of the dome.

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
pled_pocket_d = pled_body_d + 0.2;   // 8.2 - press fit on the body
pled_bore_d   = pled_dome_d + 0.5;   // 6.5 - dome clearance
pled_bore_l   = pled_body_h;         // body sits flush, whole dome outside
pled_tab_y    = cap_od/2 + nozzle_out - pled_body_h;   // where the tabs bear
// Clear space under the disc: the chamber the emitter lies in, so it scales
// with the pocket. The margin is 1.5, which puts the disc 0.5 above the seated
// LED - the disc is what stops it lifting back out of its cradle - and keeps
// the cap as short as the part allows.
shelf_gap  = pled_pocket_d + 1.5;
cap_bore   = cap_od - 2*cap_wall;    // 32
skirt_bore = neck_d + fit;           // 18.3
skirt_z    = neck_h + 0.5;           // cap seats on the shoulder, not the neck
chamber_d  = cap_bore - 6;           // 26 - wiring space under the disc
shelf_z    = neck_h + shelf_gap;     // 19.7 - top face of the shelf
disc_d     = cap_bore - fit;         // 31.7
disc_z1    = shelf_z + disc_th;      // 22.2
plug_h     = sw_body_h + roof_gap;   // roof underside sits just clear of the switch
cap_body_h = disc_z1 + plug_h;       // 26.3
plug_od    = cap_bore - fit;
plug_bore  = plug_od - 2*cap_wall;   // 27.7
roof_z0    = cap_body_h;
roof_z1    = roof_z0 + roof_th;      // 28.3 - whole cap, was 24.6 on 3 mm LEDs
bead_od    = cap_bore + 2*snap_r;
bead_ramp  = (bead_od - plug_od)/2;  // 45 deg both sides -> printable, no support
bead_z     = disc_z1 + plug_h/2;     // bead centre

rail_w = 4.0;    // tangential width of the keying rails
rail_p = 1.5;    // how far they poke into the bore

// --- nozzle boss. Sits at the chamber level, below the disc, so the whole
//     thing lives in cap_body: no channel has to cross the cap_top joint.
nozzle_z      = (skirt_z + shelf_z)/2;
// Spout: sized by the TAB SPAN, not the body, because the tabs have to sit
// inside it - they are what stops the LED pushing out the front. 1.5 of wall
// beyond each tab tip.
nozzle_tip_d  = pled_tab_span + 3.0;                           // 17.5
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

            // LED cavity, bored radially out through the nozzle
            power_led_cavity();
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

/* Cavity for the 8 mm power emitter.

   The body sits in an 8.2 bore that runs right out to the nozzle face, so it
   ends up flush and the entire 2.6 mm dome stands outside with nothing at all
   in front of it - no lip, no countersink, no vignetting, the full 120 deg.

   What holds it in is the tabs: they span 14.5 and cannot pass an 8.2 bore, so
   they bear on the ring behind it. That is the whole trick, and it is why the
   spout is sized by the tab span rather than by the body.

   Assembly: drop it in from the top of the wiring chamber with the leads
   already soldered, then push it forward until the tabs stop. The tab slot ends
   at exactly that plane. The drop-in channel above is only body-wide, because a
   full tab-width channel that high would break out through the spout.

   Printing: the channel removes what would have been the bore's ceiling, so
   nothing bridges over the LED. cap_body still prints rim up, no support. */
module power_led_cavity() {
    y_face = cap_od/2 + nozzle_out;
    y_back = chamber_d/2 - 1;                  // overshoot: tangency breaks CGAL
    // body bore, all the way out to the face
    translate([0, y_face + 0.01, nozzle_z]) rotate([90,0,0])
        cylinder(h = y_face - y_back + 0.02, d = pled_pocket_d);
    // tab slot: stops at the bearing plane, which is what retains the LED.
    // Tall enough for the stagger, and centred so either orientation fits.
    tab_h = pled_tab_w + pled_tab_stag + 0.3;
    translate([-(pled_tab_span + 0.4)/2, y_back, nozzle_z - tab_h/2])
        cube([pled_tab_span + 0.4, pled_tab_y - y_back, tab_h]);
    // drop-in channel: body-wide only, up past the shelf
    translate([-(pled_pocket_d + 0.4)/2, y_back, nozzle_z])
        cube([pled_pocket_d + 0.4, pled_tab_y - y_back, shelf_z - nozzle_z + 0.5]);
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

echo(str("LED: whole ", pled_dome_h, " dome proud, body flush; tab slot ",
         pled_tab_w + pled_tab_stag + 0.3, " tall x ", pled_tab_span + 0.4,
         " wide, bearing at y=", pled_tab_y, " on ",
         (nozzle_tip_d - pled_pocket_d)/2, " of ring; spout ", nozzle_tip_d,
         ", spout wall beside the slot ",
         sqrt(pow(nozzle_tip_d/2,2) - pow((pled_tab_w+pled_tab_stag+0.3)/2,2))
           - (pled_tab_span+0.4)/2,
         "; cap ", roof_z1, " tall"));
