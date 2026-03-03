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
            editTimesheetFormId
            (renderTimesheetForm timesheetEntry staffMembers weekOffset (UpdateTimesheetEntryAction (get #id timesheetEntry)) editTimesheetFormId PageOverlayForm)

editTimesheetFormId :: Text
editTimesheetFormId = "timesheet-entry-edit-form"

renderEditTimesheetDialog :: TimesheetEntry -> [Staff] -> Int -> Html
renderEditTimesheetDialog timesheetEntry staffMembers weekOffset =
    renderTimesheetEntryDialog
        "Edit Timesheet Entry"
        editTimesheetFormId
        (renderTimesheetForm timesheetEntry staffMembers weekOffset (UpdateTimesheetEntryAction (get #id timesheetEntry)) editTimesheetFormId HtmxOverlayForm)
