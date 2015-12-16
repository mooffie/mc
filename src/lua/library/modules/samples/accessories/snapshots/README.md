Snapshots
---------

A snapshot is a recorded state of a single panel, or of
both panels, which you can restore whenever you wish.

You can associate hotkeys with snapshots, for easier access.


The state
---------

By "state" we mean: directory, sort order, custom format string, etc.

You can choose to restore just the directory.

You can also edit the snapshots database (hit the "Raw" button) to keep
only the state you want; e.g., you can keep just the sorting order, or
just the custom format string, and remove all the rest. You can even
remove the directory!


The listing
-----------

The main dialog lists some details about the snapshots. There's a column
showing either "+" if the snapshot stores many settings, or " " if it
stores just the directory, or "P" if it stores panelization data.


Support for panelization
------------------------

A snapshot also stores the list of files shown in a panelized panel. When
you restore such snapshot, the panel becomes panelized with this list.
This is the purpose of the 'snapshot_panelized_list' property you see
when you edit the database.

But as much as 'snapshot_panelized_list' is useful, it's often more
useful to be able, instead, to re-play the shell command that generated
that file list in the first place. MC unfortunately doesn't store this
command anywhere so Snapshots can't record it in its database. But it
*does* let you yourself specify the shell command to re-play when you
restore a snapshot. You use the 'snapshot_panelized_command' property for
this. You'll have to edit the database to add it.

For example, assuming your snapshot look like this:

    {
      ...
      left = {
        dir = "/whatever/path",
        ...
      }
    }

You'd change it to:

    {
      ...
      left = {
        dir = "/whatever/path",
        ...
        , snapshot_panelized_command = "find -iname '*.mp3'"
      }
    }

(There's no sense in having both 'snapshot_panelized_list' and
'snapshot_panelized_command' in the same snapshot. But if both exist,
'snapshot_panelized_command' takes precedence.)
