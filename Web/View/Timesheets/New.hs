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
            newTimesheetFormId
            (renderTimesheetForm timesheetEntry staffMembers weekOffset CreateTimesheetEntryAction newTimesheetFormId PageOverlayForm)

newTimesheetFormId :: Text
newTimesheetFormId = "timesheet-entry-create-form"

renderNewTimesheetDialog :: TimesheetEntry -> [Staff] -> Int -> Html
renderNewTimesheetDialog timesheetEntry staffMembers weekOffset =
    renderTimesheetEntryDialog
        "New Timesheet Entry"
        newTimesheetFormId
        (renderTimesheetForm timesheetEntry staffMembers weekOffset CreateTimesheetEntryAction newTimesheetFormId HtmxOverlayForm)
