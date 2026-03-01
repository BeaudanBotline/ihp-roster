module Web.View.Timesheets.Edit where

import Web.View.Prelude

data EditView = EditView
    { timesheetEntry :: TimesheetEntry
    , staffMembers   :: [Staff]
    }

instance View EditView where
    html EditView { .. } = [hsx|
        <h1>Edit Timesheet Entry</h1>
        {renderTimesheetForm timesheetEntry staffMembers (UpdateTimesheetEntryAction timesheetEntry.id)}
        {renderQuarterHourTimePickerModal}
    |]
