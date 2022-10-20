package require Tk 8.6

namespace eval ttk::theme::azure-dark {
    variable version 2.0
    package provide ttk::theme::azure-dark $version

    ttk::style theme create azure-dark -parent clam -settings {
        proc load_images {imgdir} {
            variable I
            foreach file [glob -directory $imgdir *.png] {
                set img [file tail [file rootname $file]]
                set I($img) [image create photo -file $file -format png]
            }
        }

        load_images [file join [file dirname [info script]] dark]

        array set colors {
            -fg             "#ffffff"
            -bg             "#333333"
            -disabledfg     "#aaaaaa"
            -disabledbg     "#737373"
            -selectfg       "#ffffff"
            -selectbg       "#007fff"
        }

        ttk::style layout TButton {
            Button.button -children {
                Button.padding -children {
                    Button.label -side left -expand true
                } 
            }
        }

        ttk::style configure TButton -padding {8 4 8 4} -width -10 -anchor center

        ttk::style element create Button.button image \
            [list $I(rect-basic) \
            	{selected disabled} $I(rect-basic) \
                disabled $I(rect-basic) \
                pressed $I(rect-basic) \
                selected $I(rect-basic) \
                active $I(button-hover) \
            ] -border 4 -sticky ewns

    }
}
