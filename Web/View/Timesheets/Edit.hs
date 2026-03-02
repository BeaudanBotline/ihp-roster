module Web.View.Timesheets.Edit where

import Web.View.Prelude

data EditView = EditView
    { timesheetEntry :: TimesheetEntry
    , staffMembers   :: [Staff]
    , weekOffset     :: Int
    }

instance View EditView where
    html EditView { .. } =
        renderTimesheetEntryModal
            "Edit Timesheet Entry"
            weekOffset
            (renderTimesheetForm timesheetEntry staffMembers weekOffset (UpdateTimesheetEntryAction timesheetEntry.id))
