/*
  Digital Graffiti Spray Can Enclosure
  Modular Design with Through-Cut Alignment Grooves & External Battery Slot
*/

can_diameter = 60;
can_height = 120;
cap_height = 25;
wall_thickness = 2;

cap_outer_d = 28;
cap_inner_d = cap_outer_d - (wall_thickness * 2); 

led_hole_diam = 3.2; 

// Tactile Switch Mount Dimensions
switch_width = 12.4;     
switch_base_h = 3.5;     
switch_actuator_d = 8.0; 
pin_pitch_x = 12.5; 
pin_pitch_y = 4.5;  
pin_hole_diam = 2.0;

// External Battery Holder Dimensions (Adjust these to match your AAA_holder.3mf)
holder_w = 26.0;  // Width of external holder
holder_d = 13.0;  // Depth/thickness of external holder
holder_h = 48.0;  // Height/length of external holder
holder_tol = 0.3; // Clearance for sliding fit

$fn = 100;

// --- 1. Main Body Module ---
module main_body() {
    difference() {
        union() {
            cylinder(h=can_height, d=can_diameter);
            translate([0, 0, can_height])
                cylinder(h=15, d1=can_diameter, d2=cap_outer_d);
            translate([0, 0, can_height + 15])
                cylinder(h=8, d=cap_inner_d - 0.4); 
        }

        translate([0, 0, -wall_thickness])
        union() {
            cylinder(h=can_height, d=can_diameter - (wall_thickness*2));
            translate([0, 0, can_height])
                cylinder(h=15, d1=can_diameter - (wall_thickness*2), d2=cap_inner_d - 0.4 - (wall_thickness*2));
            translate([0, 0, can_height + 15])
                cylinder(h=12, d=cap_inner_d - 0.4 - (wall_thickness*2));
        }
    }
}

// --- 2. Detachable Top Cap Module ---
module top_cap() {
    union() {
        difference() {
            cylinder(h=cap_height, d=cap_outer_d);

            translate([0, 0, -0.1])
                cylinder(h=cap_height - wall_thickness - switch_base_h + 0.1, d=cap_inner_d);

            translate([0, 0, cap_height - 5])
                cylinder(h=10, d=switch_actuator_d);

            translate([-(switch_width/2), -(switch_width/2), cap_height - wall_thickness - switch_base_h])
                cube([switch_width, switch_width, switch_base_h + 0.1]);

            translate([-10, -6, cap_height/2])
                rotate([0, 90, 0])
                cylinder(h=30, d=led_hole_diam);

            translate([-10, 6, cap_height/2])
                rotate([0, 90, 0])
                cylinder(h=30, d=led_hole_diam);
        }
        
        // Alignment Rails
        translate([(cap_inner_d/2) - 1, -1, 0])
            cube([1, 2, cap_height - wall_thickness - switch_base_h]);
            
        translate([-(cap_inner_d/2), -1, 0])
            cube([1, 2, cap_height - wall_thickness - switch_base_h]);
    }
}

// --- 3. Bottom Lid & External Battery Holder Clip ---
module bottom_cap() {
    union() {
        // Base plate
        cylinder(h=wall_thickness, d=can_diameter);
        
        // Insert lip
        translate([0, 0, wall_thickness])
            cylinder(h=5, d=can_diameter - (wall_thickness*2) - 0.4);
            
        // Slot/Bracket for external battery holder
        translate([0, 0, wall_thickness])
        union() {
            difference() {
                // Outer retaining sleeve
                translate([0, 0, holder_h/2])
                    cube([holder_w + 4, holder_d + 4, holder_h], center=true);

                // Inner slot cavity
                translate([0, 0, holder_h/2 + 1]) 
                    cube([holder_w + (holder_tol*2), holder_d + (holder_tol*2), holder_h + 2], center=true);

                // Front cutout to allow flex (creates the snap "clip" action)
                translate([0, holder_d/2, holder_h/2 + 2])
                    cube([holder_w - 8, 4, holder_h + 2], center=true);
                    
                // Wire routing holes at the base of the slot
                translate([-6, 0, -1]) cylinder(h=5, d=3.5);
                translate([6, 0, -1]) cylinder(h=5, d=3.5);
            }
            
            // Snap-fit retention bumps (detents) inside the top of the sleeve
            translate([(holder_w/2) + holder_tol - 0.2, 0, holder_h - 4])
                sphere(d=1.5);
            translate([-((holder_w/2) + holder_tol - 0.2), 0, holder_h - 4])
                sphere(d=1.5);
        }
    }
}

// --- 4. Button Locking Disc Module ---
module button_locking_disc() {
    difference() {
        cylinder(h=2, d=cap_inner_d - 0.2);

        // 4 Pin Holes
        translate([pin_pitch_x/2, pin_pitch_y/2, -1]) cylinder(h=4, d=pin_hole_diam);
        translate([pin_pitch_x/2, -pin_pitch_y/2, -1]) cylinder(h=4, d=pin_hole_diam);
        translate([-pin_pitch_x/2, pin_pitch_y/2, -1]) cylinder(h=4, d=pin_hole_diam);
        translate([-pin_pitch_x/2, -pin_pitch_y/2, -1]) cylinder(h=4, d=pin_hole_diam);
            
        // Through-Cut Alignment Grooves
        translate([(cap_inner_d/2) - 0.5, 0, 1])
            cube([3, 2.4, 4], center=true);
            
        translate([-(cap_inner_d/2) + 0.5, 0, 1])
            cube([3, 2.4, 4], center=true);
    }
}

// --- 5. Render Layout ---
main_body();

translate([can_diameter + 15, 0, 0])
    bottom_cap();

translate([-can_diameter/2 - 15, 0, 0])
    top_cap();

translate([-can_diameter/2 - 15, cap_outer_d + 15, 0])
    button_locking_disc();