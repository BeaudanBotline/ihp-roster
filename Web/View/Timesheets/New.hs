module Web.View.Timesheets.New where

import Web.View.Prelude

data NewView = NewView
    { timesheetEntry :: TimesheetEntry
    , staffMembers   :: [Staff]
    , weekOffset     :: Int
    }

instance View NewView where
    html NewView { .. } =
        renderTimesheetEntryModal
            "New Timesheet Entry"
            weekOffset
            (renderTimesheetForm timesheetEntry staffMembers weekOffset CreateTimesheetEntryAction)
