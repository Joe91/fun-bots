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

        # Buttons
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
        

        # Entry
        ttk::style element create Entry.field \
            image [list $I(box-basic) \
                {focus hover} $I(box-accent) \
                invalid $I(box-invalid) \
                disabled $I(box-basic) \
                focus $I(box-accent) \
                hover $I(box-hover) \
            ] -border 5 -padding {8} -sticky news


        # Combobox
        ttk::style layout TCombobox {
            Combobox.field -sticky nswe -children {
                Combobox.padding -expand true -sticky nswe -children {
                    Combobox.textarea -sticky nswe
                }
            }
            Combobox.button -side right -sticky ns -children {
                Combobox.arrow -sticky nsew
            }
        }

        ttk::style map TCombobox -selectbackground [list \
            {!focus} $colors(-selectbg) \
            {readonly hover} $colors(-selectbg) \
            {readonly focus} $colors(-selectbg) \
        ]
            
        ttk::style map TCombobox -selectforeground [list \
            {!focus} $colors(-selectfg) \
            {readonly hover} $colors(-selectfg) \
            {readonly focus} $colors(-selectfg) \
        ]

        ttk::style element create Combobox.field \
            image [list $I(box-basic) \
                {readonly disabled} $I(rect-basic) \
                {readonly pressed} $I(rect-basic) \
                {readonly focus hover} $I(button-hover) \
                {readonly focus} $I(button-hover) \
                {readonly hover} $I(button-hover) \
                {focus hover} $I(box-accent) \
                readonly $I(rect-basic) \
                invalid $I(box-invalid) \
                disabled $I(box-basic) \
                focus $I(box-accent) \
                hover $I(box-hover) \
            ] -border 5 -padding {8}
            
        ttk::style element create Combobox.button \
            image [list $I(combo-button-basic) \
                 {!readonly focus} $I(combo-button-focus) \
                 {readonly focus} $I(combo-button-hover) \
                 {readonly hover} $I(combo-button-hover)
            ] -border 5 -padding {2 6 6 6}

        ttk::style element create Combobox.arrow image $I(down) \
            -width 15 -sticky e

    }
}
